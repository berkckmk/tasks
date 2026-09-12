import type {
  DataGateway,
  DocumentData,
  DocumentRow,
  QueryFilter,
  QuerySpec,
  Unsubscribe,
} from './data-gateway.ts';

const DELETE_FIELD = Symbol('memory-delete-field');

type Watcher = {
  path: string;
  query: QuerySpec;
  onData: (rows: DocumentRow[]) => void;
  onError: (error: unknown) => void;
};

type DocumentWatcher = {
  path: string;
  onData: (row: DocumentRow | null) => void;
  onError: (error: unknown) => void;
};

function comparable(value: unknown): unknown {
  return value instanceof Date ? value.getTime() : value;
}

function matches(data: DocumentData, filter: QueryFilter) {
  const left = comparable(data[filter.field]);
  const right = comparable(filter.value);
  if (filter.operator === '==') return left === right;
  if (filter.operator === 'in') return Array.isArray(right) && right.includes(left);
  if (filter.operator === '>=') return (left as number | string) >= (right as number | string);
  if (filter.operator === '>') return (left as number | string) > (right as number | string);
  if (filter.operator === '<=') return (left as number | string) <= (right as number | string);
  return (left as number | string) < (right as number | string);
}

function materialize(data: DocumentData) {
  return Object.fromEntries(Object.entries(data).filter(([, value]) => value !== DELETE_FIELD));
}

/** Synthetic development gateway. It never opens a Firebase connection. */
export class MemoryDataGateway implements DataGateway {
  private readonly collections = new Map<string, Map<string, DocumentData>>();
  private readonly watchers = new Set<Watcher>();
  private readonly documentWatchers = new Set<DocumentWatcher>();
  private readonly authenticatedUserId: string;
  private sequence = 0;

  constructor(authenticatedUserId = 'preview-user') {
    this.authenticatedUserId = authenticatedUserId;
  }

  watchCollection(
    path: string,
    query: QuerySpec,
    onData: (rows: DocumentRow[]) => void,
    onError: (error: unknown) => void,
  ): Unsubscribe {
    const watcher = { path, query, onData, onError };
    this.watchers.add(watcher);
    this.emit(watcher);
    return () => this.watchers.delete(watcher);
  }

  watchDocument(
    path: string,
    onData: (row: DocumentRow | null) => void,
    onError: (error: unknown) => void,
  ): Unsubscribe {
    const watcher = { path, onData, onError };
    this.documentWatchers.add(watcher);
    this.emitDocument(watcher);
    return () => this.documentWatchers.delete(watcher);
  }

  async getDocument(path: string): Promise<DocumentRow | null> {
    const { collectionPath, id } = this.splitDocumentPath(path);
    const data = this.collection(collectionPath).get(id);
    return data ? { id, data: { ...data } } : null;
  }

  async getCollection(path: string, query: QuerySpec) {
    return this.rows(path, query);
  }

  async callFunction(name: string, data: DocumentData) {
    if (name !== 'createTask' && name !== 'createHabit') {
      throw new Error(`Unsupported synthetic function: ${name}`);
    }
    const collectionName = name === 'createTask' ? 'tasks' : 'habits';
    const userPath = `users/${this.authenticatedUserId}`;
    const path = `${userPath}/${collectionName}`;
    const id = typeof data.clientMutationId === 'string'
      ? `widget_${encodeURIComponent(data.clientMutationId)}`
      : this.nextId(collectionName.slice(0, -1));
    const callableData = name === 'createTask'
      ? {
          ...data,
          startDate: typeof data.startDate === 'string' ? new Date(data.startDate) : null,
          dueDate: typeof data.dueDate === 'string' ? new Date(data.dueDate) : null,
          status: 'todo',
        }
      : data;
    await this.setDocument(`${path}/${id}`, {
      ...callableData,
      createdAt: this.serverTimestamp(),
      updatedAt: this.serverTimestamp(),
    }, { merge: true });
    return { id };
  }

  async addDocument(path: string, data: DocumentData) {
    const id = this.nextId('item');
    await this.setDocument(`${path}/${id}`, data);
    return { id };
  }

  async setDocument(path: string, data: DocumentData, options?: { merge?: boolean }) {
    const { collectionPath, id } = this.splitDocumentPath(path);
    const collection = this.collection(collectionPath);
    const existing = options?.merge ? collection.get(id) ?? {} : {};
    const combined = { ...existing, ...data };
    for (const [key, value] of Object.entries(combined)) {
      if (value === DELETE_FIELD) delete combined[key];
    }
    collection.set(id, materialize(combined));
    this.notify(collectionPath);
  }

  async updateDocument(path: string, data: DocumentData) {
    const { collectionPath, id } = this.splitDocumentPath(path);
    if (!this.collection(collectionPath).has(id)) throw new Error(`Missing document: ${path}`);
    await this.setDocument(path, data, { merge: true });
  }

  async deleteDocument(path: string) {
    const { collectionPath, id } = this.splitDocumentPath(path);
    this.collection(collectionPath).delete(id);
    this.notify(collectionPath);
  }

  async deleteDocuments(paths: string[]) {
    for (const path of paths) await this.deleteDocument(path);
  }

  serverTimestamp() {
    return new Date();
  }

  deleteField() {
    return DELETE_FIELD;
  }

  private rows(path: string, query: QuerySpec) {
    let rows = [...this.collection(path)].map(([id, data]) => ({ id, data: { ...data } }));
    for (const filter of query.filters ?? []) rows = rows.filter((row) => matches(row.data, filter));
    if (query.orderBy) {
      const { field, direction = 'asc' } = query.orderBy;
      const multiplier = direction === 'asc' ? 1 : -1;
      rows.sort((a, b) => {
        const left = comparable(a.data[field]);
        const right = comparable(b.data[field]);
        if (left === right) return 0;
        return (left === undefined || (left as number | string) < (right as number | string) ? -1 : 1)
          * multiplier;
      });
    }
    return query.limit ? rows.slice(0, query.limit) : rows;
  }

  private emit(watcher: Watcher) {
    try {
      watcher.onData(this.rows(watcher.path, watcher.query));
    } catch (error) {
      watcher.onError(error);
    }
  }

  private emitDocument(watcher: DocumentWatcher) {
    try {
      const { collectionPath, id } = this.splitDocumentPath(watcher.path);
      const data = this.collection(collectionPath).get(id);
      watcher.onData(data ? { id, data: { ...data } } : null);
    } catch (error) {
      watcher.onError(error);
    }
  }

  private notify(path: string) {
    for (const watcher of this.watchers) if (watcher.path === path) this.emit(watcher);
    for (const watcher of this.documentWatchers) {
      const { collectionPath } = this.splitDocumentPath(watcher.path);
      if (collectionPath === path) this.emitDocument(watcher);
    }
  }

  private collection(path: string) {
    let collection = this.collections.get(path);
    if (!collection) {
      collection = new Map();
      this.collections.set(path, collection);
    }
    return collection;
  }

  private splitDocumentPath(path: string) {
    const separator = path.lastIndexOf('/');
    if (separator <= 0 || separator === path.length - 1) throw new Error(`Invalid document path: ${path}`);
    return { collectionPath: path.slice(0, separator), id: path.slice(separator + 1) };
  }

  private nextId(prefix: string) {
    this.sequence += 1;
    return `${prefix}-${this.sequence}`;
  }
}

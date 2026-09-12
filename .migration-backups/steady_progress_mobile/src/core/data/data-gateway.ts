export type DocumentData = Record<string, unknown>;
export type DocumentRow = { id: string; data: DocumentData };

export type QueryFilter = {
  field: string;
  operator: '==' | '>=' | '>' | '<=' | '<' | 'in';
  value: unknown;
};

export type QuerySpec = {
  orderBy?: { field: string; direction?: 'asc' | 'desc' };
  filters?: QueryFilter[];
  limit?: number;
};

export type Unsubscribe = () => void;

/** Firebase-independent boundary used by every feature repository. */
export interface DataGateway {
  watchCollection(
    path: string,
    query: QuerySpec,
    onData: (rows: DocumentRow[]) => void,
    onError: (error: unknown) => void,
  ): Unsubscribe;
  watchDocument(
    path: string,
    onData: (row: DocumentRow | null) => void,
    onError: (error: unknown) => void,
  ): Unsubscribe;
  getDocument(path: string): Promise<DocumentRow | null>;
  getCollection(path: string, query: QuerySpec): Promise<DocumentRow[]>;
  callFunction(name: string, data: DocumentData): Promise<DocumentData>;
  addDocument(path: string, data: DocumentData): Promise<{ id: string }>;
  setDocument(path: string, data: DocumentData, options?: { merge?: boolean }): Promise<void>;
  updateDocument(path: string, data: DocumentData): Promise<void>;
  deleteDocument(path: string): Promise<void>;
  deleteDocuments(paths: string[]): Promise<void>;
  serverTimestamp(): unknown;
  deleteField(): unknown;
}

export function userCollection(userId: string, collection: string) {
  if (!userId.trim()) throw new Error('Authenticated user id is required');
  return `users/${userId}/${collection}`;
}

/** Stable Firestore document id for retryable native/widget mutations. */
export function clientMutationDocumentId(clientMutationId: string) {
  const trimmed = clientMutationId.trim();
  if (!trimmed || trimmed.length > 128) throw new Error('Invalid client mutation id');
  return `widget_${encodeURIComponent(trimmed)}`;
}

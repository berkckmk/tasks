import { addDoc, collection, deleteDoc, deleteField, doc, getDoc, getDocs, getFirestore, limit, onSnapshot, orderBy, query as makeQuery, serverTimestamp, setDoc, updateDoc, where, writeBatch, type Query } from '@react-native-firebase/firestore';
import { getFunctions, httpsCallable } from '@react-native-firebase/functions';
import type { DataGateway, DocumentData, DocumentRow, QuerySpec, Unsubscribe } from './data-gateway.ts';

function queryFor(path: string, spec: QuerySpec) {
  const constraints = [
    ...(spec.filters ?? []).map((filter) => where(filter.field, filter.operator, filter.value)),
    ...(spec.orderBy ? [orderBy(spec.orderBy.field, spec.orderBy.direction ?? 'asc')] : []),
    ...(spec.limit ? [limit(spec.limit)] : []),
  ];
  return makeQuery(collection(getFirestore(), path), ...constraints) as Query;
}

/**
 * Resolves as soon as the write is committed to local cache or acknowledged by the server,
 * with a fallback timeout (2000ms) to ensure slow/reconnecting network streams never freeze the UI.
 */
async function optimisticCommit(promise: Promise<unknown>, timeoutMs = 2000): Promise<void> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<void>((resolve) => {
    timer = setTimeout(resolve, timeoutMs);
  });
  await Promise.race([
    promise.then(() => {
      if (timer) clearTimeout(timer);
    }),
    timeoutPromise,
  ]);
}

/** React Native Firebase implementation used only by configured production hosts. */
export class FirebaseDataGateway implements DataGateway {
  watchCollection(path: string, query: QuerySpec, onData: (rows: DocumentRow[]) => void, onError: (error: unknown) => void): Unsubscribe {
    return onSnapshot(queryFor(path, query), (snapshot) => onData(snapshot.docs.map((item) => ({ id: item.id, data: item.data({ serverTimestamps: 'estimate' }) }))), onError);
  }
  watchDocument(path: string, onData: (row: DocumentRow | null) => void, onError: (error: unknown) => void): Unsubscribe {
    return onSnapshot(
      doc(getFirestore(), path),
      (snapshot) => {
        onData(snapshot.exists() ? { id: snapshot.id, data: snapshot.data({ serverTimestamps: 'estimate' }) ?? {} } : null);
      },
      onError,
    );
  }
  async getDocument(path: string): Promise<DocumentRow | null> {
    const snapshot = await getDoc(doc(getFirestore(), path));
    return snapshot.exists() ? { id: snapshot.id, data: snapshot.data({ serverTimestamps: 'estimate' }) ?? {} } : null;
  }
  async getCollection(path: string, query: QuerySpec) { const snapshot = await getDocs(queryFor(path, query)); return snapshot.docs.map((item) => ({ id: item.id, data: item.data({ serverTimestamps: 'estimate' }) })); }
  async callFunction(name: string, data: DocumentData): Promise<DocumentData> {
    const fn = httpsCallable(getFunctions(), name, { timeout: 12000 });
    const timeoutPromise = new Promise<never>((_, reject) => {
      setTimeout(
        () => reject(new Error('İşlem zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.')),
        12000,
      );
    });
    const result = await Promise.race([fn(data), timeoutPromise]);
    return result.data && typeof result.data === 'object' ? (result.data as DocumentData) : {};
  }
  async addDocument(path: string, data: DocumentData): Promise<{ id: string }> {
    const reference = doc(collection(getFirestore(), path));
    await optimisticCommit(setDoc(reference, data));
    return { id: reference.id };
  }
  setDocument(path: string, data: DocumentData, options?: { merge?: boolean }): Promise<void> {
    return optimisticCommit(setDoc(doc(getFirestore(), path), data, { merge: options?.merge ?? false }));
  }
  updateDocument(path: string, data: DocumentData): Promise<void> {
    return optimisticCommit(updateDoc(doc(getFirestore(), path), data));
  }
  deleteDocument(path: string): Promise<void> {
    return optimisticCommit(deleteDoc(doc(getFirestore(), path)));
  }
  async deleteDocuments(paths: string[]): Promise<void> {
    const batch = writeBatch(getFirestore());
    paths.forEach((path) => batch.delete(doc(getFirestore(), path)));
    await optimisticCommit(batch.commit());
  }
  serverTimestamp() { return serverTimestamp(); }
  deleteField() { return deleteField(); }
}

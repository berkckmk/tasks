import {
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query as makeQuery,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  type Query,
  type QueryConstraint,
  type WhereFilterOp,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { getFirebaseWebFirestore, getFirebaseWebFunctions } from '../firebase/firebase-web-config';
import type { DataGateway, DocumentData, DocumentRow, QuerySpec, Unsubscribe } from './data-gateway';

function queryFor(path: string, spec: QuerySpec) {
  const db = getFirebaseWebFirestore();
  const constraints: QueryConstraint[] = [
    ...(spec.filters ?? []).map((filter) =>
      where(filter.field, filter.operator as WhereFilterOp, filter.value),
    ),
    ...(spec.orderBy ? [orderBy(spec.orderBy.field, spec.orderBy.direction ?? 'asc')] : []),
    ...(spec.limit ? [limit(spec.limit)] : []),
  ];
  return makeQuery(collection(db, path), ...constraints) as Query;
}

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

export class FirebaseDataGateway implements DataGateway {
  watchCollection(
    path: string,
    query: QuerySpec,
    onData: (rows: DocumentRow[]) => void,
    onError: (error: unknown) => void,
  ): Unsubscribe {
    return onSnapshot(
      queryFor(path, query),
      (snapshot) => {
        onData(
          snapshot.docs.map((item) => ({
            id: item.id,
            data: (item.data({ serverTimestamps: 'estimate' }) as DocumentData) ?? {},
          })),
        );
      },
      (error) => {
        console.error('[WEB_GATEWAY_WATCH_COLLECTION_ERROR]', path, error);
        onError(error);
      },
    );
  }

  watchDocument(
    path: string,
    onData: (row: DocumentRow | null) => void,
    onError: (error: unknown) => void,
  ): Unsubscribe {
    const db = getFirebaseWebFirestore();
    return onSnapshot(
      doc(db, path),
      (snapshot) => {
        onData(
          snapshot.exists()
            ? {
                id: snapshot.id,
                data: (snapshot.data({ serverTimestamps: 'estimate' }) as DocumentData) ?? {},
              }
            : null,
        );
      },
      (error) => {
        console.error('[WEB_GATEWAY_WATCH_DOCUMENT_ERROR]', path, error);
        onError(error);
      },
    );
  }

  async getDocument(path: string): Promise<DocumentRow | null> {
    const db = getFirebaseWebFirestore();
    const snapshot = await getDoc(doc(db, path));
    return snapshot.exists()
      ? {
          id: snapshot.id,
          data: (snapshot.data({ serverTimestamps: 'estimate' }) as DocumentData) ?? {},
        }
      : null;
  }

  async getCollection(path: string, query: QuerySpec): Promise<DocumentRow[]> {
    const snapshot = await getDocs(queryFor(path, query));
    return snapshot.docs.map((item) => ({
      id: item.id,
      data: (item.data({ serverTimestamps: 'estimate' }) as DocumentData) ?? {},
    }));
  }

  async callFunction(name: string, data: DocumentData): Promise<DocumentData> {
    const functions = getFirebaseWebFunctions();
    const fn = httpsCallable(functions, name, { timeout: 12000 });
    const timeoutPromise = new Promise<never>((_, reject) => {
      setTimeout(
        () =>
          reject(
            new Error(
              'İşlem zaman aşımına uğradı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.',
            ),
          ),
        12000,
      );
    });
    const result = await Promise.race([fn(data), timeoutPromise]);
    return result.data && typeof result.data === 'object' ? (result.data as DocumentData) : {};
  }

  async addDocument(path: string, data: DocumentData): Promise<{ id: string }> {
    const db = getFirebaseWebFirestore();
    const reference = doc(collection(db, path));
    await optimisticCommit(setDoc(reference, data));
    return { id: reference.id };
  }

  setDocument(path: string, data: DocumentData, options?: { merge?: boolean }): Promise<void> {
    const db = getFirebaseWebFirestore();
    return optimisticCommit(
      setDoc(doc(db, path), data, { merge: options?.merge ?? false }),
    );
  }

  updateDocument(path: string, data: DocumentData): Promise<void> {
    const db = getFirebaseWebFirestore();
    return optimisticCommit(updateDoc(doc(db, path), data));
  }

  deleteDocument(path: string): Promise<void> {
    const db = getFirebaseWebFirestore();
    return optimisticCommit(deleteDoc(doc(db, path)));
  }

  async deleteDocuments(paths: string[]): Promise<void> {
    const db = getFirebaseWebFirestore();
    const batch = writeBatch(db);
    paths.forEach((path) => batch.delete(doc(db, path)));
    await optimisticCommit(batch.commit());
  }

  serverTimestamp(): unknown {
    return serverTimestamp();
  }

  deleteField(): unknown {
    return deleteField();
  }
}

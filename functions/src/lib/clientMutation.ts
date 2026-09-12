/** The RN client uses the same encoding for durable widget quick-add ids. */
export function clientMutationDocumentId(clientMutationId: string): string {
  return `widget_${encodeURIComponent(clientMutationId)}`;
}

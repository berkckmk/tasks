import * as ImagePicker from 'expo-image-picker';
import { getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import type { DataGateway } from '../../core/data/data-gateway';
import { getFirebaseWebStorage } from '../../core/firebase/firebase-web-config';

export async function pickAndUploadAvatar(gateway: DataGateway, userId: string): Promise<string | null> {
  const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!permission.granted) throw new Error('Fotoğraf kitaplığı izni gerekli.');
  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images'],
    allowsEditing: true,
    aspect: [1, 1],
    quality: 0.82,
  });
  if (result.canceled || !result.assets[0]?.uri) return null;

  const storage = getFirebaseWebStorage();
  const reference = ref(storage, `users/${userId}/avatar.jpg`);

  const response = await fetch(result.assets[0].uri);
  const blob = await response.blob();
  await uploadBytes(reference, blob);

  const photoUrl = await getDownloadURL(reference);
  await gateway.setDocument(
    `users/${userId}`,
    { photoUrl, updatedAt: gateway.serverTimestamp() },
    { merge: true },
  );
  return photoUrl;
}

import { getDownloadURL, getStorage, putFile, ref } from '@react-native-firebase/storage';
import * as ImagePicker from 'expo-image-picker';
import type { DataGateway } from '../../core/data/data-gateway.ts';

export async function pickAndUploadAvatar(gateway: DataGateway, userId: string) {
  const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!permission.granted) throw new Error('Fotoğraf kitaplığı izni gerekli.');
  const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsEditing: true, aspect: [1, 1], quality: 0.82 });
  if (result.canceled || !result.assets[0]?.uri) return null;
  const reference = ref(getStorage(), `users/${userId}/avatar.jpg`);
  await putFile(reference, result.assets[0].uri.replace(/^file:\/\//, ''));
  const photoUrl = await getDownloadURL(reference);
  await gateway.setDocument(`users/${userId}`, { photoUrl, updatedAt: gateway.serverTimestamp() }, { merge: true });
  return photoUrl;
}

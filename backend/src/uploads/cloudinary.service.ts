import { Injectable } from '@nestjs/common';
import { v2 as cloudinary } from 'cloudinary';

@Injectable()
export class CloudinaryService {
  constructor() {
    cloudinary.config({
      cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
      api_key: process.env.CLOUDINARY_API_KEY,
      api_secret: process.env.CLOUDINARY_API_SECRET,
    });
  }

  /**
   * Extract the public_id from a Cloudinary URL
   * e.g. https://res.cloudinary.com/df2uwb7tz/image/upload/v123/agente-multibanco/receipts/abc.webp
   * → agente-multibanco/receipts/abc
   */
  extractPublicId(url: string): string | null {
    try {
      const match = url.match(/\/upload\/(?:v\d+\/)?(agente-multibanco\/receipts\/[^.]+)/);
      return match ? match[1] : null;
    } catch {
      return null;
    }
  }

  /**
   * Delete a single image from Cloudinary by URL
   */
  async deleteByUrl(url: string): Promise<void> {
    const publicId = this.extractPublicId(url);
    if (!publicId) return;
    try {
      await cloudinary.uploader.destroy(publicId);
    } catch (error) {
      console.error(`Failed to delete Cloudinary image ${publicId}:`, error);
    }
  }

  /**
   * Delete multiple images from Cloudinary by URLs
   */
  async deleteMultipleByUrls(urls: string[]): Promise<void> {
    const publicIds = urls
      .map((url) => this.extractPublicId(url))
      .filter((id): id is string => id !== null);

    if (publicIds.length === 0) return;

    // Delete in batches of 100 (Cloudinary limit)
    for (let i = 0; i < publicIds.length; i += 100) {
      const batch = publicIds.slice(i, i + 100);
      try {
        await cloudinary.api.delete_resources(batch);
      } catch (error) {
        console.error('Failed to batch delete Cloudinary images:', error);
      }
    }
  }
}

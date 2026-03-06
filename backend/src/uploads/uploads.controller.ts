import {
  Controller, Post, Req, UseGuards,
  BadRequestException, InternalServerErrorException,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiBearerAuth, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { v2 as cloudinary } from 'cloudinary';
import { Readable } from 'stream';

@ApiTags('Uploads')
@ApiBearerAuth()
@UseGuards(AuthGuard('jwt'))
@Controller('uploads')
export class UploadsController {
  constructor() {
    cloudinary.config({
      cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
      api_key: process.env.CLOUDINARY_API_KEY,
      api_secret: process.env.CLOUDINARY_API_SECRET,
    });
  }

  @Post('receipt')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  async uploadReceipt(@Req() req: FastifyRequest) {
    const data = await (req as any).file();
    if (!data) {
      throw new BadRequestException('No se proporcionó ningún archivo');
    }

    const allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowedMimes.includes(data.mimetype)) {
      throw new BadRequestException('Tipo de archivo no permitido. Use JPG, PNG o WebP');
    }

    try {
      const chunks: Buffer[] = [];
      for await (const chunk of data.file) {
        chunks.push(chunk);
      }
      const buffer = Buffer.concat(chunks);

      const result = await new Promise<any>((resolve, reject) => {
        const uploadStream = cloudinary.uploader.upload_stream(
          {
            folder: 'agente-multibanco/receipts',
            format: 'webp',
            quality: 'auto:good',
            transformation: [
              { width: 1200, height: 1200, crop: 'limit' },
            ],
          },
          (error, result) => {
            if (error) reject(error);
            else resolve(result);
          },
        );

        const readable = Readable.from(buffer);
        readable.pipe(uploadStream);
      });

      return {
        url: result.secure_url,
        publicId: result.public_id,
        filename: `${result.public_id}.webp`,
      };
    } catch (error) {
      console.error('Cloudinary upload error:', error);
      throw new InternalServerErrorException('Error al subir la imagen');
    }
  }
}

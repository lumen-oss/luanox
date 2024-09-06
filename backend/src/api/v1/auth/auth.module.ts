import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { JwtStrategy, GithubStrategy } from './auth.service';
import { AuthController } from './auth.controller';

@Module({
  providers: [JwtStrategy, GithubStrategy],
  controllers: [AuthController],
  imports: [
    JwtModule.registerAsync({
      useFactory: async (configService: ConfigService) => {
        return {
          signOptions: { expiresIn: '12h' },
          secret: configService.get<string>('JWT_SECRET'),
        };
      },
      inject: [ConfigService],
    }),
  ]
})
export class AuthModule {}

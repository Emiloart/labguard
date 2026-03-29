import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().default('0.0.0.0'),
  PORT: z.coerce.number().int().positive().default(8080),
  LOG_LEVEL: z
    .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent'])
    .default('info'),
  DATABASE_URL: z.string().min(1),
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  VPN_SERVER_DEFAULT_REGION: z.enum(['uk-lon', 'us-sfo']).default('uk-lon'),
  VPN_SERVER_LONDON_ENDPOINT: z.string().default(''),
  VPN_SERVER_LONDON_PUBLIC_KEY: z.string().default(''),
  VPN_SERVER_LONDON_EXIT_IP: z.string().default(''),
  VPN_SERVER_LONDON_DNS: z.string().default('1.1.1.1,1.0.0.1'),
  VPN_SERVER_SF_ENDPOINT: z.string().default(''),
  VPN_SERVER_SF_PUBLIC_KEY: z.string().default(''),
  VPN_SERVER_SF_EXIT_IP: z.string().default(''),
  VPN_SERVER_SF_DNS: z.string().default('1.1.1.1,1.0.0.1'),
});

export type AppEnv = z.infer<typeof envSchema>;

export const env = envSchema.parse(process.env);

/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'img.clerk.com',
      },
    ],
  },
  async redirects() {
    return [
      {
        source: '/',
        destination: '/sign-in',
        permanent: false, // Используйте true для постоянного перенаправления (HTTP 301)
      },
    ];
  },
};

export default nextConfig;

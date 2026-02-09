/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Increase timeout for API proxying (5 minutes for model loading)
  experimental: {
    proxyTimeout: 300000, // 5 minutes in milliseconds
  },
  // Proxy API requests to backend
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: 'http://127.0.0.1:8000/api/:path*',
      },
      {
        source: '/health',
        destination: 'http://127.0.0.1:8000/health',
      },
    ];
  },
}

module.exports = nextConfig

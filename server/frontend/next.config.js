/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Ensure we can work behind Nginx proxy
  async rewrites() {
    return [];
  },
}

module.exports = nextConfig

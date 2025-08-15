const express = require('express');
const client = require('prom-client');

const app = express();
const port = process.env.PORT || 3000;

// Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.5, 1, 2, 5],
});

register.registerMetric(httpRequestsTotal);
register.registerMetric(httpRequestDuration);

// Middleware to track metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path)
      .observe(duration);
    
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .inc();
  });
  
  next();
});

// Routes
app.get('/', (req, res) => {
  const environment = process.env.NODE_ENV || 'development';
  res.json({
    message: `Hello World from Thrive ${environment.toUpperCase()}! 🚀`,
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || '1.0.0',
    environment: environment,
    hostname: require('os').hostname(),
    branch: 'dev',
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    pid: process.pid,
  });
});

app.get('/ready', (req, res) => {
  // Add more sophisticated readiness checks here
  // For now, simple check that server is running
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString(),
  });
});

app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    res.status(500).end(error);
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});

app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Thrive Hello World app listening on port ${port}`);
  console.log(`📊 Metrics available at http://localhost:${port}/metrics`);
  console.log(`❤️  Health check at http://localhost:${port}/health`);
});

module.exports = app;

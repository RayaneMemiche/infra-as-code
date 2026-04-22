require('dotenv').config();

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const promClient = require('prom-client');
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./swagger');
const taskStore = require('./taskStore');
const { initDB, checkConnection } = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

// ============================================================================
// PROMETHEUS METRICS (C4 Section 6.3)
// ============================================================================

// Collect default Node.js metrics (CPU, memory, event loop, etc.)
promClient.collectDefaultMetrics({ prefix: 'taskmanager_' });

// HTTP request counter
const httpRequestCounter = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status']
});

// HTTP request duration histogram
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
});

// Active requests gauge
const activeRequests = new promClient.Gauge({
  name: 'http_requests_active',
  help: 'Number of active HTTP requests'
});

// Database query counter
const dbQueryCounter = new promClient.Counter({
  name: 'db_queries_total',
  help: 'Total number of database queries',
  labelNames: ['operation', 'status']
});

// Task counter gauge
const taskGauge = new promClient.Gauge({
  name: 'tasks_total',
  help: 'Total number of tasks in the system'
});

// Configuration
const API_TOKEN = process.env.API_TOKEN || 'dev-token-change-in-production';
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX_REQUESTS = parseInt(process.env.RATE_LIMIT_MAX || '100', 10);

// Simple in-memory rate limiter
const rateLimitStore = new Map();

// ============================================================================
// MIDDLEWARE
// ============================================================================

// JSON body parser
app.use(express.json());

// Prometheus metrics middleware - track all requests
app.use((req, res, next) => {
  // Skip metrics endpoint to avoid recursion
  if (req.path === '/metrics') {
    return next();
  }

  const start = Date.now();
  activeRequests.inc();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    const labels = {
      method: req.method,
      route: route,
      status: res.statusCode
    };

    httpRequestCounter.inc(labels);
    httpRequestDuration.observe(labels, duration);
    activeRequests.dec();
  });

  next();
});

// Correlation ID middleware (C4 Section 5)
// Generates correlation_id if not provided, adds to all responses
app.use((req, res, next) => {
  const correlationId = req.headers['x-correlation-id'] || uuidv4();
  req.correlationId = correlationId;
  res.setHeader('x-correlation-id', correlationId);
  next();
});

// Rate limiting middleware (C4 Section 5 - HTTP 429)
const rateLimitMiddleware = (req, res, next) => {
  const clientId = req.headers['x-client-id'] || req.ip || 'anonymous';
  const now = Date.now();

  // Clean old entries
  for (const [key, data] of rateLimitStore.entries()) {
    if (now - data.windowStart > RATE_LIMIT_WINDOW_MS) {
      rateLimitStore.delete(key);
    }
  }

  // Check rate limit
  let clientData = rateLimitStore.get(clientId);
  if (!clientData || now - clientData.windowStart > RATE_LIMIT_WINDOW_MS) {
    clientData = { windowStart: now, count: 0 };
  }

  clientData.count++;
  rateLimitStore.set(clientId, clientData);

  // Set rate limit headers
  res.setHeader('X-RateLimit-Limit', RATE_LIMIT_MAX_REQUESTS);
  res.setHeader('X-RateLimit-Remaining', Math.max(0, RATE_LIMIT_MAX_REQUESTS - clientData.count));
  res.setHeader('X-RateLimit-Reset', Math.ceil((clientData.windowStart + RATE_LIMIT_WINDOW_MS) / 1000));

  if (clientData.count > RATE_LIMIT_MAX_REQUESTS) {
    return res.status(429).json({
      error: 'Too Many Requests',
      message: 'Rate limit exceeded. Please try again later.',
      correlation_id: req.correlationId,
      retry_after: Math.ceil((clientData.windowStart + RATE_LIMIT_WINDOW_MS - now) / 1000)
    });
  }

  next();
};

// Authentication middleware (C4 Section 5)
// Validates Authorization: Bearer <token>
const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing Authorization header',
      correlation_id: req.correlationId
    });
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid Authorization header format. Expected: Bearer <token>',
      correlation_id: req.correlationId
    });
  }

  const token = parts[1];
  if (token !== API_TOKEN) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid or expired token',
      correlation_id: req.correlationId
    });
  }

  next();
};

// ============================================================================
// SWAGGER DOCUMENTATION
// ============================================================================

// Serve Swagger UI at /api-docs
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  explorer: true,
  customSiteTitle: 'Task Manager API Documentation',
  customCss: '.swagger-ui .topbar { display: none }',
  swaggerOptions: {
    persistAuthorization: true,
  },
}));

// Serve raw OpenAPI spec
app.get('/api-docs.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

// ============================================================================
// HEALTH & READINESS ENDPOINTS (No auth required)
// ============================================================================

/**
 * @openapi
 * /health:
 *   get:
 *     tags:
 *       - Health
 *     summary: Health check endpoint
 *     description: Returns the health status of the API. Used by Kubernetes liveness probe.
 *     responses:
 *       200:
 *         description: API is healthy
 *         headers:
 *           X-Correlation-ID:
 *             $ref: '#/components/headers/X-Correlation-ID'
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/HealthResponse'
 *             example:
 *               status: healthy
 *               timestamp: "2025-01-24T10:30:00.000Z"
 *               correlation_id: "123e4567-e89b-12d3-a456-426614174000"
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    correlation_id: req.correlationId
  });
});

/**
 * @openapi
 * /ready:
 *   get:
 *     tags:
 *       - Health
 *     summary: Readiness check endpoint
 *     description: Checks if the API is ready to serve requests (database connectivity). Used by Kubernetes readiness probe.
 *     responses:
 *       200:
 *         description: API is ready
 *         headers:
 *           X-Correlation-ID:
 *             $ref: '#/components/headers/X-Correlation-ID'
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ReadyResponse'
 *             example:
 *               ready: true
 *               timestamp: "2025-01-24T10:30:00.000Z"
 *               correlation_id: "123e4567-e89b-12d3-a456-426614174000"
 *       503:
 *         description: API is not ready (database unavailable)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ServiceUnavailableError'
 */
app.get('/ready', async (req, res) => {
  try {
    const dbReady = await checkConnection();

    if (!dbReady) {
      return res.status(503).json({
        ready: false,
        reason: 'Database connection unavailable',
        timestamp: new Date().toISOString(),
        correlation_id: req.correlationId
      });
    }

    res.json({
      ready: true,
      timestamp: new Date().toISOString(),
      correlation_id: req.correlationId
    });
  } catch (err) {
    res.status(503).json({
      ready: false,
      reason: 'Health check failed',
      timestamp: new Date().toISOString(),
      correlation_id: req.correlationId
    });
  }
});

/**
 * @openapi
 * /metrics:
 *   get:
 *     tags:
 *       - Metrics
 *     summary: Prometheus metrics endpoint
 *     description: Returns Prometheus-formatted metrics for monitoring. Used by ServiceMonitor for scraping.
 *     responses:
 *       200:
 *         description: Prometheus metrics in text format
 *         content:
 *           text/plain:
 *             schema:
 *               type: string
 *             example: |
 *               # HELP http_requests_total Total number of HTTP requests
 *               # TYPE http_requests_total counter
 *               http_requests_total{method="GET",route="/health",status="200"} 42
 *               # HELP tasks_total Total number of tasks in the system
 *               # TYPE tasks_total gauge
 *               tasks_total 5
 *       500:
 *         description: Error collecting metrics
 */
app.get('/metrics', async (req, res) => {
  try {
    // Update task gauge before returning metrics
    const tasks = await taskStore.getAll();
    taskGauge.set(tasks.length);

    res.set('Content-Type', promClient.register.contentType);
    res.end(await promClient.register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

// ============================================================================
// PROTECTED ROUTES (Auth + Rate Limiting required)
// ============================================================================

// Apply rate limiting and auth to /tasks routes
app.use('/tasks', rateLimitMiddleware, authMiddleware);

/**
 * @openapi
 * /tasks:
 *   get:
 *     tags:
 *       - Tasks
 *     summary: List all tasks
 *     description: Retrieves all tasks from the database
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of tasks retrieved successfully
 *         headers:
 *           X-Correlation-ID:
 *             $ref: '#/components/headers/X-Correlation-ID'
 *           X-RateLimit-Limit:
 *             $ref: '#/components/headers/X-RateLimit-Limit'
 *           X-RateLimit-Remaining:
 *             $ref: '#/components/headers/X-RateLimit-Remaining'
 *           X-RateLimit-Reset:
 *             $ref: '#/components/headers/X-RateLimit-Reset'
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/TaskListResponse'
 *             example:
 *               data:
 *                 - id: "550e8400-e29b-41d4-a716-446655440000"
 *                   title: "Complete documentation"
 *                   content: "Write API docs"
 *                   due_date: "2025-02-15T18:00:00.000Z"
 *                   done: false
 *                   request_timestamp: "2025-01-24T10:30:00.000Z"
 *               correlation_id: "123e4567-e89b-12d3-a456-426614174000"
 *       401:
 *         description: Unauthorized - Missing or invalid token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/UnauthorizedError'
 *       429:
 *         description: Rate limit exceeded
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/RateLimitError'
 */
app.get('/tasks', async (req, res, next) => {
  try {
    const tasks = await taskStore.getAll();
    res.json({
      data: tasks,
      correlation_id: req.correlationId
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @openapi
 * /tasks:
 *   post:
 *     tags:
 *       - Tasks
 *     summary: Create a new task
 *     description: Creates a new task with the provided data. Title must be unique.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/CreateTaskRequest'
 *           examples:
 *             basic:
 *               summary: Basic task
 *               value:
 *                 title: "Complete documentation"
 *             full:
 *               summary: Task with all fields
 *               value:
 *                 title: "Complete project documentation"
 *                 content: "Write comprehensive API documentation"
 *                 due_date: "2025-02-15T18:00:00.000Z"
 *                 request_timestamp: "2025-01-24T10:30:00.000Z"
 *     responses:
 *       201:
 *         description: Task created successfully
 *         headers:
 *           X-Correlation-ID:
 *             $ref: '#/components/headers/X-Correlation-ID'
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/TaskResponse'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             examples:
 *               missingTitle:
 *                 summary: Missing title
 *                 value:
 *                   error: "Validation failed"
 *                   message: "Title is required and must be a non-empty string"
 *                   correlation_id: "123e4567-e89b-12d3-a456-426614174000"
 *               invalidDate:
 *                 summary: Invalid due_date
 *                 value:
 *                   error: "Validation failed"
 *                   message: "due_date must be a valid ISO datetime string"
 *                   correlation_id: "123e4567-e89b-12d3-a456-426614174000"
 *       401:
 *         description: Unauthorized
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/UnauthorizedError'
 *       409:
 *         description: Conflict - Task with same title already exists
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ConflictError'
 *       429:
 *         description: Rate limit exceeded
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/RateLimitError'
 */
app.post('/tasks', async (req, res, next) => {
  try {
    const { title, content, due_date, request_timestamp } = req.body;

    // Validation
    if (!title || typeof title !== 'string' || title.trim() === '') {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Title is required and must be a non-empty string',
        correlation_id: req.correlationId
      });
    }

    // Validate due_date format if provided
    if (due_date && isNaN(Date.parse(due_date))) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'due_date must be a valid ISO datetime string',
        correlation_id: req.correlationId
      });
    }

    // Validate request_timestamp if provided (C4 Section 5)
    let parsedTimestamp = null;
    if (request_timestamp) {
      if (isNaN(Date.parse(request_timestamp))) {
        return res.status(400).json({
          error: 'Validation failed',
          message: 'request_timestamp must be a valid ISO datetime string',
          correlation_id: req.correlationId
        });
      }
      parsedTimestamp = request_timestamp;
    }

    // Check for duplicate title (for 409 Conflict)
    const existingTasks = await taskStore.getAll();
    const duplicate = existingTasks.find(t => t.title.toLowerCase() === title.trim().toLowerCase());
    if (duplicate) {
      return res.status(409).json({
        error: 'Conflict',
        message: `A task with title '${title.trim()}' already exists`,
        existing_task_id: duplicate.id,
        correlation_id: req.correlationId
      });
    }

    const task = await taskStore.create({
      title: title.trim(),
      content,
      due_date,
      request_timestamp: parsedTimestamp
    });

    res.status(201).json({
      data: task,
      correlation_id: req.correlationId
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @openapi
 * /tasks/{id}:
 *   get:
 *     tags:
 *       - Tasks
 *     summary: Get a task by ID
 *     description: Retrieves a specific task by its UUID
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: Task UUID
 *         schema:
 *           type: string
 *           format: uuid
 *         example: "550e8400-e29b-41d4-a716-446655440000"
 *     responses:
 *       200:
 *         description: Task retrieved successfully
 *         headers:
 *           X-Correlation-ID:
 *             $ref: '#/components/headers/X-Correlation-ID'
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/TaskResponse'
 *       401:
 *         description: Unauthorized
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/UnauthorizedError'
 *       404:
 *         description: Task not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/NotFoundError'
 *       429:
 *         description: Rate limit exceeded
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/RateLimitError'
 */
app.get('/tasks/:id', async (req, res, next) => {
  try {
    const task = await taskStore.getById(req.params.id);

    if (!task) {
      return res.status(404).json({
        error: 'Not found',
        message: `Task with id '${req.params.id}' not found`,
        correlation_id: req.correlationId
      });
    }

    res.json({
      data: task,
      correlation_id: req.correlationId
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @openapi
 * /tasks/{id}:
 *   put:
 *     tags:
 *       - Tasks
 *     summary: Update a task
 *     description: Updates an existing task. Supports partial updates (only provided fields are updated).
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: Task UUID
 *         schema:
 *           type: string
 *           format: uuid
 *         example: "550e8400-e29b-41d4-a716-446655440000"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/UpdateTaskRequest'
 *           examples:
 *             markDone:
 *               summary: Mark task as done
 *               value:
 *                 done: true
 *             updateContent:
 *               summary: Update content and due date
 *               value:
 *                 content: "Updated task description"
 *                 due_date: "2025-03-01T12:00:00.000Z"
 *             fullUpdate:
 *               summary: Full update
 *               value:
 *                 title: "Updated title"
 *                 content: "Updated content"
 *                 due_date: "2025-03-01T12:00:00.000Z"
 *                 done: true
 *     responses:
 *       200:
 *         description: Task updated successfully
 *         headers:
 *           X-Correlation-ID:
 *             $ref: '#/components/headers/X-Correlation-ID'
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/TaskResponse'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Unauthorized
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/UnauthorizedError'
 *       404:
 *         description: Task not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/NotFoundError'
 *       409:
 *         description: Conflict - Task with same title already exists
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ConflictError'
 *       429:
 *         description: Rate limit exceeded
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/RateLimitError'
 */
app.put('/tasks/:id', async (req, res, next) => {
  try {
    const { title, content, due_date, done, request_timestamp } = req.body;

    // Validate title if provided
    if (title !== undefined && (typeof title !== 'string' || title.trim() === '')) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Title must be a non-empty string',
        correlation_id: req.correlationId
      });
    }

    // Validate due_date format if provided
    if (due_date !== undefined && due_date !== null && isNaN(Date.parse(due_date))) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'due_date must be a valid ISO datetime string',
        correlation_id: req.correlationId
      });
    }

    // Validate done if provided
    if (done !== undefined && typeof done !== 'boolean') {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'done must be a boolean',
        correlation_id: req.correlationId
      });
    }

    // Validate request_timestamp if provided
    if (request_timestamp !== undefined && request_timestamp !== null && isNaN(Date.parse(request_timestamp))) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'request_timestamp must be a valid ISO datetime string',
        correlation_id: req.correlationId
      });
    }

    // Check for title conflict with other tasks (409 Conflict)
    if (title !== undefined) {
      const existingTasks = await taskStore.getAll();
      const duplicate = existingTasks.find(
        t => t.id !== req.params.id && t.title.toLowerCase() === title.trim().toLowerCase()
      );
      if (duplicate) {
        return res.status(409).json({
          error: 'Conflict',
          message: `A task with title '${title.trim()}' already exists`,
          existing_task_id: duplicate.id,
          correlation_id: req.correlationId
        });
      }
    }

    const updatedTask = await taskStore.update(req.params.id, {
      title: title?.trim(),
      content,
      due_date,
      done,
      request_timestamp
    });

    if (!updatedTask) {
      return res.status(404).json({
        error: 'Not found',
        message: `Task with id '${req.params.id}' not found`,
        correlation_id: req.correlationId
      });
    }

    res.json({
      data: updatedTask,
      correlation_id: req.correlationId
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @openapi
 * /tasks/{id}:
 *   delete:
 *     tags:
 *       - Tasks
 *     summary: Delete a task
 *     description: Permanently deletes a task by its UUID
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: Task UUID
 *         schema:
 *           type: string
 *           format: uuid
 *         example: "550e8400-e29b-41d4-a716-446655440000"
 *     responses:
 *       204:
 *         description: Task deleted successfully (no content)
 *         headers:
 *           X-Correlation-ID:
 *             $ref: '#/components/headers/X-Correlation-ID'
 *       401:
 *         description: Unauthorized
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/UnauthorizedError'
 *       404:
 *         description: Task not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/NotFoundError'
 *       429:
 *         description: Rate limit exceeded
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/RateLimitError'
 */
app.delete('/tasks/:id', async (req, res, next) => {
  try {
    const deleted = await taskStore.delete(req.params.id);

    if (!deleted) {
      return res.status(404).json({
        error: 'Not found',
        message: `Task with id '${req.params.id}' not found`,
        correlation_id: req.correlationId
      });
    }

    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// ============================================================================
// ERROR HANDLING
// ============================================================================

// 404 handler for unknown routes
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    message: `Route ${req.method} ${req.path} not found`,
    correlation_id: req.correlationId
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: 'An unexpected error occurred',
    correlation_id: req.correlationId
  });
});

// ============================================================================
// SERVER STARTUP
// ============================================================================

const startServer = async () => {
  try {
    await initDB();
    app.listen(PORT, () => {
      console.log(`Task Manager API running on port ${PORT}`);
      console.log(`\nEndpoints:`);
      console.log(`  Swagger UI:     http://localhost:${PORT}/api-docs`);
      console.log(`  OpenAPI JSON:   http://localhost:${PORT}/api-docs.json`);
      console.log(`  Health check:   http://localhost:${PORT}/health`);
      console.log(`  Readiness:      http://localhost:${PORT}/ready`);
      console.log(`  Metrics:        http://localhost:${PORT}/metrics`);
      console.log(`  Tasks API:      http://localhost:${PORT}/tasks`);
      console.log(`\nAuthentication required for /tasks: Authorization: Bearer <token>`);
      console.log(`Default token (dev only): ${API_TOKEN}`);
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
};

startServer();

module.exports = app;

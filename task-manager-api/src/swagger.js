const swaggerJsdoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.3',
    info: {
      title: 'Task Manager API',
      version: '1.0.0',
      description: 'A RESTful API for managing tasks with authentication, rate limiting, and Prometheus metrics',
      contact: {
        name: 'Epitech C4 Project',
      },
      license: {
        name: 'MIT',
      },
    },
    servers: [
      {
        url: 'http://104.155.52.234',
        description: 'GKE Production (LoadBalancer)',
      },
    ],
    tags: [
      {
        name: 'Health',
        description: 'Health and readiness endpoints (no authentication required)',
      },
      {
        name: 'Tasks',
        description: 'Task CRUD operations (authentication required)',
      },
      {
        name: 'Metrics',
        description: 'Prometheus metrics endpoint',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Enter your API token (default dev token: dev-token-change-in-production)',
        },
      },
      schemas: {
        // ====== Request DTOs ======
        CreateTaskRequest: {
          type: 'object',
          required: ['title'],
          properties: {
            title: {
              type: 'string',
              minLength: 1,
              maxLength: 255,
              description: 'Task title (must be unique)',
              example: 'Complete project documentation',
            },
            content: {
              type: 'string',
              description: 'Task description or content',
              example: 'Write comprehensive documentation for the API endpoints',
            },
            due_date: {
              type: 'string',
              format: 'date-time',
              description: 'Task due date in ISO 8601 format',
              example: '2025-02-15T18:00:00.000Z',
            },
            request_timestamp: {
              type: 'string',
              format: 'date-time',
              description: 'Client-side timestamp of the request',
              example: '2025-01-24T10:30:00.000Z',
            },
          },
        },
        UpdateTaskRequest: {
          type: 'object',
          properties: {
            title: {
              type: 'string',
              minLength: 1,
              maxLength: 255,
              description: 'Task title (must be unique)',
              example: 'Updated task title',
            },
            content: {
              type: 'string',
              description: 'Task description or content',
              example: 'Updated task content',
            },
            due_date: {
              type: 'string',
              format: 'date-time',
              nullable: true,
              description: 'Task due date in ISO 8601 format (null to clear)',
              example: '2025-03-01T12:00:00.000Z',
            },
            done: {
              type: 'boolean',
              description: 'Task completion status',
              example: true,
            },
            request_timestamp: {
              type: 'string',
              format: 'date-time',
              description: 'Client-side timestamp of the request',
              example: '2025-01-24T11:00:00.000Z',
            },
          },
        },
        // ====== Response DTOs ======
        Task: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              format: 'uuid',
              description: 'Unique task identifier',
              example: '550e8400-e29b-41d4-a716-446655440000',
            },
            title: {
              type: 'string',
              description: 'Task title',
              example: 'Complete project documentation',
            },
            content: {
              type: 'string',
              description: 'Task description',
              example: 'Write comprehensive documentation for the API endpoints',
            },
            due_date: {
              type: 'string',
              format: 'date-time',
              nullable: true,
              description: 'Task due date',
              example: '2025-02-15T18:00:00.000Z',
            },
            done: {
              type: 'boolean',
              description: 'Task completion status',
              example: false,
            },
            request_timestamp: {
              type: 'string',
              format: 'date-time',
              description: 'Timestamp when task was created/updated',
              example: '2025-01-24T10:30:00.000Z',
            },
          },
        },
        TaskResponse: {
          type: 'object',
          properties: {
            data: {
              $ref: '#/components/schemas/Task',
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
              description: 'Request correlation ID for tracing',
              example: '123e4567-e89b-12d3-a456-426614174000',
            },
          },
        },
        TaskListResponse: {
          type: 'object',
          properties: {
            data: {
              type: 'array',
              items: {
                $ref: '#/components/schemas/Task',
              },
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
              description: 'Request correlation ID for tracing',
              example: '123e4567-e89b-12d3-a456-426614174000',
            },
          },
        },
        HealthResponse: {
          type: 'object',
          properties: {
            status: {
              type: 'string',
              enum: ['healthy'],
              description: 'Health status',
              example: 'healthy',
            },
            timestamp: {
              type: 'string',
              format: 'date-time',
              description: 'Current server timestamp',
              example: '2025-01-24T10:30:00.000Z',
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
              example: '123e4567-e89b-12d3-a456-426614174000',
            },
          },
        },
        ReadyResponse: {
          type: 'object',
          properties: {
            ready: {
              type: 'boolean',
              description: 'Readiness status',
              example: true,
            },
            timestamp: {
              type: 'string',
              format: 'date-time',
              example: '2025-01-24T10:30:00.000Z',
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
              example: '123e4567-e89b-12d3-a456-426614174000',
            },
          },
        },
        // ====== Error DTOs ======
        ErrorResponse: {
          type: 'object',
          properties: {
            error: {
              type: 'string',
              description: 'Error type',
              example: 'Validation failed',
            },
            message: {
              type: 'string',
              description: 'Detailed error message',
              example: 'Title is required and must be a non-empty string',
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
              example: '123e4567-e89b-12d3-a456-426614174000',
            },
          },
        },
        UnauthorizedError: {
          type: 'object',
          properties: {
            error: {
              type: 'string',
              example: 'Unauthorized',
            },
            message: {
              type: 'string',
              example: 'Missing Authorization header',
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
            },
          },
        },
        NotFoundError: {
          type: 'object',
          properties: {
            error: {
              type: 'string',
              example: 'Not found',
            },
            message: {
              type: 'string',
              example: "Task with id '550e8400-e29b-41d4-a716-446655440000' not found",
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
            },
          },
        },
        ConflictError: {
          type: 'object',
          properties: {
            error: {
              type: 'string',
              example: 'Conflict',
            },
            message: {
              type: 'string',
              example: "A task with title 'My Task' already exists",
            },
            existing_task_id: {
              type: 'string',
              format: 'uuid',
              description: 'ID of the existing task with same title',
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
            },
          },
        },
        RateLimitError: {
          type: 'object',
          properties: {
            error: {
              type: 'string',
              example: 'Too Many Requests',
            },
            message: {
              type: 'string',
              example: 'Rate limit exceeded. Please try again later.',
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
            },
            retry_after: {
              type: 'integer',
              description: 'Seconds until rate limit resets',
              example: 45,
            },
          },
        },
        ServiceUnavailableError: {
          type: 'object',
          properties: {
            ready: {
              type: 'boolean',
              example: false,
            },
            reason: {
              type: 'string',
              example: 'Database connection unavailable',
            },
            timestamp: {
              type: 'string',
              format: 'date-time',
            },
            correlation_id: {
              type: 'string',
              format: 'uuid',
            },
          },
        },
      },
      headers: {
        'X-Correlation-ID': {
          description: 'Unique request identifier for tracing',
          schema: {
            type: 'string',
            format: 'uuid',
          },
        },
        'X-RateLimit-Limit': {
          description: 'Maximum requests allowed per window',
          schema: {
            type: 'integer',
            example: 100,
          },
        },
        'X-RateLimit-Remaining': {
          description: 'Remaining requests in current window',
          schema: {
            type: 'integer',
            example: 95,
          },
        },
        'X-RateLimit-Reset': {
          description: 'Unix timestamp when the rate limit resets',
          schema: {
            type: 'integer',
            example: 1706093400,
          },
        },
      },
    },
  },
  apis: ['./src/index.js', './src/routes/*.js'],
};

const swaggerSpec = swaggerJsdoc(options);

module.exports = swaggerSpec;

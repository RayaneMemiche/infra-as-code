const request = require('supertest');

// ---------------------------------------------------------------------------
// Mock modules BEFORE requiring the app.
// Using the `mock` prefix is required by Jest for variables referenced inside
// jest.mock() factory functions.
// ---------------------------------------------------------------------------

// Mock the database module so no real PG connection is attempted
jest.mock('../db', () => ({
  pool: { query: jest.fn() },
  initDB: jest.fn().mockResolvedValue(undefined),
  checkConnection: jest.fn().mockResolvedValue(true),
}));

// Mock taskStore — implementations are wired up in beforeEach via the
// required mock reference so we can share mutable state (mockTasks).
jest.mock('../taskStore', () => ({
  getAll: jest.fn(),
  getById: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
}));

// Clear the Prometheus default registry so metrics registered by the app do
// not collide between test re-runs (Jest may re-require modules).
const promClient = require('prom-client');
promClient.register.clear();

// Now require the app – the mocks are already in place so startServer()'s
// initDB() call resolves immediately.
const app = require('../index');
const { checkConnection } = require('../db');
const taskStore = require('../taskStore');

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------
const API_TOKEN = 'dev-token-change-in-production';
const authHeader = `Bearer ${API_TOKEN}`;

// In-memory task list shared across mock implementations
let mockTasks = [];

// ---------------------------------------------------------------------------
// Reset state between tests
// ---------------------------------------------------------------------------
beforeEach(() => {
  mockTasks = [];
  checkConnection.mockResolvedValue(true);

  // Wire up taskStore mock implementations that operate on mockTasks
  taskStore.getAll.mockImplementation(async () => mockTasks);

  taskStore.getById.mockImplementation(async (id) => {
    return mockTasks.find((t) => t.id === id) || null;
  });

  taskStore.create.mockImplementation(async (data) => {
    const task = {
      id: 'test-uuid-' + (mockTasks.length + 1),
      title: data.title,
      content: data.content || '',
      due_date: data.due_date || null,
      done: false,
      request_timestamp: data.request_timestamp || new Date().toISOString(),
    };
    mockTasks.push(task);
    return task;
  });

  taskStore.update.mockImplementation(async (id, data) => {
    const idx = mockTasks.findIndex((t) => t.id === id);
    if (idx === -1) return null;
    const current = mockTasks[idx];
    const updated = {
      ...current,
      title: data.title !== undefined ? data.title : current.title,
      content: data.content !== undefined ? data.content : current.content,
      due_date: data.due_date !== undefined ? data.due_date : current.due_date,
      done: data.done !== undefined ? data.done : current.done,
      request_timestamp:
        data.request_timestamp !== undefined
          ? data.request_timestamp
          : current.request_timestamp,
    };
    mockTasks[idx] = updated;
    return updated;
  });

  taskStore.delete.mockImplementation(async (id) => {
    const idx = mockTasks.findIndex((t) => t.id === id);
    if (idx === -1) return false;
    mockTasks.splice(idx, 1);
    return true;
  });
});

// ---------------------------------------------------------------------------
// Health & Readiness (no auth required)
// ---------------------------------------------------------------------------

describe('GET /health', () => {
  it('returns 200 with status "healthy"', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
  });
});

describe('GET /ready', () => {
  it('returns 200 when database is reachable', async () => {
    const res = await request(app).get('/ready');
    expect(res.status).toBe(200);
    expect(res.body.ready).toBe(true);
  });

  it('returns 503 when database is unreachable', async () => {
    checkConnection.mockResolvedValue(false);
    const res = await request(app).get('/ready');
    expect(res.status).toBe(503);
    expect(res.body.ready).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Authentication
// ---------------------------------------------------------------------------

describe('GET /tasks (auth)', () => {
  it('returns 401 without Authorization header', async () => {
    const res = await request(app).get('/tasks');
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('Unauthorized');
  });

  it('returns 200 with valid Bearer token', async () => {
    const res = await request(app)
      .get('/tasks')
      .set('Authorization', authHeader);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(Array.isArray(res.body.data)).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Task CRUD
// ---------------------------------------------------------------------------

describe('POST /tasks', () => {
  it('creates a task and returns 201', async () => {
    const res = await request(app)
      .post('/tasks')
      .set('Authorization', authHeader)
      .send({ title: 'New Task', content: 'Some content' });

    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({
      title: 'New Task',
      content: 'Some content',
      done: false,
    });
    expect(res.body.data.id).toBeDefined();
  });

  it('returns 400 without title', async () => {
    const res = await request(app)
      .post('/tasks')
      .set('Authorization', authHeader)
      .send({ content: 'No title here' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Validation failed');
  });

  it('returns 409 when title already exists', async () => {
    // Seed a task first
    mockTasks.push({
      id: 'existing-id',
      title: 'Duplicate',
      content: '',
      due_date: null,
      done: false,
      request_timestamp: new Date().toISOString(),
    });

    const res = await request(app)
      .post('/tasks')
      .set('Authorization', authHeader)
      .send({ title: 'Duplicate' });

    expect(res.status).toBe(409);
    expect(res.body.error).toBe('Conflict');
  });
});

describe('GET /tasks/:id', () => {
  it('returns the task when it exists', async () => {
    mockTasks.push({
      id: 'task-1',
      title: 'My Task',
      content: 'Details',
      due_date: null,
      done: false,
      request_timestamp: new Date().toISOString(),
    });

    const res = await request(app)
      .get('/tasks/task-1')
      .set('Authorization', authHeader);

    expect(res.status).toBe(200);
    expect(res.body.data.title).toBe('My Task');
  });

  it('returns 404 with invalid id', async () => {
    const res = await request(app)
      .get('/tasks/nonexistent-id')
      .set('Authorization', authHeader);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Not found');
  });
});

describe('PUT /tasks/:id', () => {
  it('updates the task', async () => {
    mockTasks.push({
      id: 'task-upd',
      title: 'Original',
      content: 'Old content',
      due_date: null,
      done: false,
      request_timestamp: new Date().toISOString(),
    });

    const res = await request(app)
      .put('/tasks/task-upd')
      .set('Authorization', authHeader)
      .send({ title: 'Updated', done: true });

    expect(res.status).toBe(200);
    expect(res.body.data.title).toBe('Updated');
    expect(res.body.data.done).toBe(true);
  });

  it('returns 404 when task does not exist', async () => {
    const res = await request(app)
      .put('/tasks/nonexistent')
      .set('Authorization', authHeader)
      .send({ title: 'Nope' });

    expect(res.status).toBe(404);
  });
});

describe('DELETE /tasks/:id', () => {
  it('deletes the task and returns 204', async () => {
    mockTasks.push({
      id: 'task-del',
      title: 'To Delete',
      content: '',
      due_date: null,
      done: false,
      request_timestamp: new Date().toISOString(),
    });

    const res = await request(app)
      .delete('/tasks/task-del')
      .set('Authorization', authHeader);

    expect(res.status).toBe(204);
  });

  it('returns 404 with invalid id', async () => {
    const res = await request(app)
      .delete('/tasks/nonexistent')
      .set('Authorization', authHeader);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Not found');
  });
});

// ---------------------------------------------------------------------------
// Rate limiting
// ---------------------------------------------------------------------------

describe('Rate limiting', () => {
  it('returns 429 after exceeding the limit', async () => {
    // The app defaults RATE_LIMIT_MAX to 100. We fire 101 requests with the
    // same X-Client-Id to exceed the limit. A unique client id ensures prior
    // tests do not interfere.
    const clientId = 'rate-limit-test-client';
    let lastRes;

    for (let i = 0; i <= 100; i++) {
      lastRes = await request(app)
        .get('/tasks')
        .set('Authorization', authHeader)
        .set('X-Client-Id', clientId);
    }

    expect(lastRes.status).toBe(429);
    expect(lastRes.body.error).toBe('Too Many Requests');
  });
});

// ---------------------------------------------------------------------------
// Prometheus metrics
// ---------------------------------------------------------------------------

describe('GET /metrics', () => {
  it('returns prometheus metrics', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/text/);
    // Should contain at least one of our custom metrics
    expect(res.text).toMatch(/http_requests_total/);
  });
});

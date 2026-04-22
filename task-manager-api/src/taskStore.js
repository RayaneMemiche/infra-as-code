const { v4: uuidv4 } = require('uuid');
const { pool } = require('./db');

/**
 * Task model:
 * {
 *   id: string (uuid),
 *   title: string,
 *   content: string,
 *   due_date: string (ISO datetime),
 *   done: boolean,
 *   request_timestamp: string (ISO datetime)
 * }
 */

const taskStore = {
  // Get all tasks
  getAll: async () => {
    const result = await pool.query('SELECT * FROM tasks ORDER BY request_timestamp DESC');
    return result.rows.map(formatTask);
  },

  // Get task by ID
  getById: async (id) => {
    const result = await pool.query('SELECT * FROM tasks WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return null;
    }
    return formatTask(result.rows[0]);
  },

  // Create a new task
  create: async (taskData) => {
    const id = uuidv4();
    // C4 Section 5: Use request_timestamp from body if provided, otherwise use NOW()
    const timestamp = taskData.request_timestamp || new Date().toISOString();
    const result = await pool.query(
      `INSERT INTO tasks (id, title, content, due_date, done, request_timestamp)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [id, taskData.title, taskData.content || '', taskData.due_date || null, false, timestamp]
    );
    return formatTask(result.rows[0]);
  },

  // Update an existing task
  update: async (id, taskData) => {
    // First check if task exists
    const existing = await pool.query('SELECT * FROM tasks WHERE id = $1', [id]);
    if (existing.rows.length === 0) {
      return null;
    }

    const current = existing.rows[0];
    const result = await pool.query(
      `UPDATE tasks SET
        title = $1,
        content = $2,
        due_date = $3,
        done = $4,
        request_timestamp = $5
       WHERE id = $6
       RETURNING *`,
      [
        taskData.title !== undefined ? taskData.title : current.title,
        taskData.content !== undefined ? taskData.content : current.content,
        taskData.due_date !== undefined ? taskData.due_date : current.due_date,
        taskData.done !== undefined ? taskData.done : current.done,
        taskData.request_timestamp !== undefined ? taskData.request_timestamp : current.request_timestamp,
        id
      ]
    );
    return formatTask(result.rows[0]);
  },

  // Delete a task
  delete: async (id) => {
    const result = await pool.query('DELETE FROM tasks WHERE id = $1 RETURNING id', [id]);
    return result.rows.length > 0;
  }
};

// Format task from DB row to API response
function formatTask(row) {
  return {
    id: row.id,
    title: row.title,
    content: row.content,
    due_date: row.due_date ? row.due_date.toISOString() : null,
    done: row.done,
    request_timestamp: row.request_timestamp.toISOString()
  };
}

module.exports = taskStore;

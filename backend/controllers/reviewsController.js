const db = require('../db');

exports.getReviews = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM reviews ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createReview = async (req, res) => {
  try {
    const { title, rating, comment } = req.body;

    await db.query(
      'INSERT INTO reviews (title, rating, comment) VALUES (?, ?, ?)',
      [title, rating, comment]
    );

    res.json({ message: 'Review added' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
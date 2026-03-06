import { useEffect, useState } from 'react';
import styles from '../styles/Home.module.css';

const BACKEND_URL = 'http://INTERNAL-CLB-DNS:3010';

export default function Home() {
  const [reviews, setReviews] = useState([]);
  const [form, setForm] = useState({ title: '', rating: '', comment: '' });

  const fetchReviews = async () => {
    const res = await fetch(`${BACKEND_URL}/api/reviews`);
    const data = await res.json();
    setReviews(data);
  };

  useEffect(() => {
    fetchReviews();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();

    await fetch(`${BACKEND_URL}/api/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form)
    });

    setForm({ title: '', rating: '', comment: '' });
    fetchReviews();
  };

  return (
    <div className={styles.container}>
      <h1>Movie Reviews</h1>

      <form onSubmit={handleSubmit} className={styles.form}>
        <input
          className={styles.inputField}
          placeholder="Movie Title"
          value={form.title}
          onChange={e => setForm({ ...form, title: e.target.value })}
          required
        />
        <input
          className={styles.inputField}
          type="number"
          placeholder="Rating (1-5)"
          min="1"
          max="5"
          value={form.rating}
          onChange={e => setForm({ ...form, rating: e.target.value })}
          required
        />
        <textarea
          className={styles.inputField}
          placeholder="Comment"
          value={form.comment}
          onChange={e => setForm({ ...form, comment: e.target.value })}
        />
        <button className={styles.button} type="submit">Add Review</button>
      </form>

      <div className={styles.list}>
        {reviews.map(review => (
          <div key={review.id} className={styles.card}>
            <h3>{review.title}</h3>
            <p>⭐ {review.rating}</p>
            <p>{review.comment}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
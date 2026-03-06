const express = require('express');
const cors = require('cors');
require('dotenv').config();

const reviewRoutes = require('./routes/reviews');

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/reviews', reviewRoutes);

app.get('/health', (req, res) => {
  res.send('Backend is healthy');
});

app.listen(process.env.PORT, () => {
  console.log(`Server running on port ${process.env.PORT}`);
});
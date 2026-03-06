const express = require('express');
const router = express.Router();
const controller = require('../controllers/reviewsController');

router.get('/', controller.getReviews);
router.post('/', controller.createReview);

module.exports = router;
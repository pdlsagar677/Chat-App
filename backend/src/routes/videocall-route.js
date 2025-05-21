// routes/videocall-route.js
import express from 'express';

const router = express.Router();

router.get('/videocall', (req, res) => {
  res.send('Video call route is working.');
});

export default router;

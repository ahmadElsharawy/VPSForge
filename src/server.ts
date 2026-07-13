import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import bodyParser from 'body-parser';
import path from 'path';
import { fileURLToPath } from 'url';
import { registerPortForwardRoutes } from './routes/portForwardRoutes.js';

const app = express();
const port = Number(process.env.PORT || 3000);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

app.use(helmet());
app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, '..', 'public')));

registerPortForwardRoutes(app);

app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

app.listen(port, () => {
  console.log(`Port Forward Manager listening on http://localhost:${port}`);
});

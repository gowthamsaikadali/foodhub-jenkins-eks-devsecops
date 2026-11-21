import { Link } from 'react-router-dom';
import EmptyState from '../components/EmptyState';

export default function NotFound() {
  return <EmptyState title="404 - Page not found"><Link to="/" className="btn">Go home</Link></EmptyState>;
}

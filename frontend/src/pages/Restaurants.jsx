import { useState } from 'react';
import EmptyState from '../components/EmptyState';
import ErrorMessage from '../components/ErrorMessage';
import Loader from '../components/Loader';
import RestaurantCard from '../components/RestaurantCard';
import useFetch from '../hooks/useFetch';
import { catalogService } from '../services/catalogService';

export default function Restaurants() {
  const [q, setQ] = useState('');
  const [applied, setApplied] = useState('');
  const { data, loading, error, reload } = useFetch(() => catalogService.restaurants(applied), [applied]);

  return (
    <>
      <div className="row-between">
        <h1>Restaurants</h1>
        <form onSubmit={(e) => { e.preventDefault(); setApplied(q.trim()); }} style={{ display: 'flex', gap: '.5rem' }}>
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Name, cuisine or city" aria-label="Search restaurants" />
          <button className="btn">Search</button>
        </form>
      </div>
      {loading && <Loader />}
      <ErrorMessage message={error} onRetry={reload} />
      {data && data.length === 0 && <EmptyState title="No restaurants found">Try a different search.</EmptyState>}
      {data && <div className="grid" style={{ marginTop: '1rem' }}>{data.map((r) => <RestaurantCard key={r.id} restaurant={r} />)}</div>}
    </>
  );
}

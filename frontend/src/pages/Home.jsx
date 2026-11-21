import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ErrorMessage from '../components/ErrorMessage';
import Loader from '../components/Loader';
import RestaurantCard from '../components/RestaurantCard';
import useFetch from '../hooks/useFetch';
import { catalogService } from '../services/catalogService';

export default function Home() {
  const [q, setQ] = useState('');
  const navigate = useNavigate();
  const { data, loading, error, reload } = useFetch(() => catalogService.restaurants());

  const onSearch = (e) => {
    e.preventDefault();
    navigate(`/menu?q=${encodeURIComponent(q.trim())}`);
  };

  return (
    <>
      <section className="hero">
        <h1>Hungry? Get your favourite food delivered.</h1>
        <p className="muted">Browse restaurants, build your cart and track your order live.</p>
        <form onSubmit={onSearch}>
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search for biryani, pizza, dessert..." aria-label="Search food" />
          <button className="btn">Search</button>
        </form>
      </section>

      <h2 className="section-title">Popular restaurants</h2>
      {loading && <Loader />}
      <ErrorMessage message={error} onRetry={reload} />
      {data && <div className="grid">{data.slice(0, 6).map((r) => <RestaurantCard key={r.id} restaurant={r} />)}</div>}
    </>
  );
}

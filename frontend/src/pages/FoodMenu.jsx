import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import EmptyState from '../components/EmptyState';
import ErrorMessage from '../components/ErrorMessage';
import FoodCard from '../components/FoodCard';
import Loader from '../components/Loader';
import useFetch from '../hooks/useFetch';
import { catalogService } from '../services/catalogService';

/** Search every available dish across all restaurants. */
export default function FoodMenu() {
  const [params, setParams] = useSearchParams();
  const q = params.get('q') || '';
  const categoryId = params.get('categoryId') || '';
  const [text, setText] = useState(q);

  const categories = useFetch(() => catalogService.categories());
  const foods = useFetch(() => catalogService.searchFoods(q, categoryId), [q, categoryId]);

  const update = (next) => {
    const p = new URLSearchParams(params);
    Object.entries(next).forEach(([k, v]) => (v ? p.set(k, v) : p.delete(k)));
    setParams(p);
  };

  return (
    <>
      <h1>Find your food</h1>
      <form className="row-between" onSubmit={(e) => { e.preventDefault(); update({ q: text.trim() }); }}>
        <input style={{ flex: 1, minWidth: 200 }} value={text} onChange={(e) => setText(e.target.value)} placeholder="Search dishes" aria-label="Search dishes" />
        <select style={{ width: 'auto' }} value={categoryId} onChange={(e) => update({ categoryId: e.target.value })} aria-label="Category">
          <option value="">All categories</option>
          {(categories.data || []).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
        <button className="btn">Search</button>
      </form>

      {foods.loading && <Loader />}
      <ErrorMessage message={foods.error} onRetry={foods.reload} />
      {foods.data && foods.data.length === 0 && <EmptyState title="Nothing matched">Try another word or category.</EmptyState>}
      {foods.data && <div className="grid" style={{ marginTop: '1rem' }}>{foods.data.map((f) => <FoodCard key={f.id} food={f} showRestaurant />)}</div>}
    </>
  );
}

import { Link, useParams } from 'react-router-dom';
import EmptyState from '../components/EmptyState';
import ErrorMessage from '../components/ErrorMessage';
import FoodCard from '../components/FoodCard';
import Loader from '../components/Loader';
import useFetch from '../hooks/useFetch';
import { catalogService } from '../services/catalogService';

export default function RestaurantDetails() {
  const { id } = useParams();
  const info = useFetch(() => catalogService.restaurant(id), [id]);
  const menu = useFetch(() => catalogService.menu(id), [id]);

  if (info.loading) return <Loader />;
  if (info.error) return <><ErrorMessage message={info.error} onRetry={info.reload} /><Link to="/restaurants">← All restaurants</Link></>;

  const r = info.data;
  const grouped = (menu.data || []).reduce((acc, f) => {
    const key = f.categoryName || 'Other';
    (acc[key] = acc[key] || []).push(f);
    return acc;
  }, {});

  return (
    <>
      <Link to="/restaurants">← All restaurants</Link>
      <div className="card" style={{ marginTop: '1rem' }}>
        {r.imageUrl && <img src={r.imageUrl} alt={r.name} style={{ height: 240 }} />}
        <div className="card-body">
          <div className="row-between"><h1>{r.name}</h1><span className="rating">★ {Number(r.rating).toFixed(1)}</span></div>
          <p className="muted">{r.cuisine} · {r.address}, {r.city}{r.phone ? ` · ${r.phone}` : ''}</p>
          <p>{r.description}</p>
        </div>
      </div>

      <h2 className="section-title">Menu</h2>
      {menu.loading && <Loader />}
      <ErrorMessage message={menu.error} onRetry={menu.reload} />
      {menu.data && menu.data.length === 0 && <EmptyState title="No items on the menu yet" />}
      {Object.entries(grouped).map(([category, items]) => (
        <section key={category}>
          <h3 style={{ marginTop: '1.5rem' }}>{category}</h3>
          <div className="grid">{items.map((f) => <FoodCard key={f.id} food={f} />)}</div>
        </section>
      ))}
    </>
  );
}

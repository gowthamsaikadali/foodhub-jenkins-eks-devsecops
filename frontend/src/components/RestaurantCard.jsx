import { Link } from 'react-router-dom';

const FALLBACK = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800';

export default function RestaurantCard({ restaurant }) {
  return (
    <Link to={`/restaurants/${restaurant.id}`} className="card restaurant-card">
      <img src={restaurant.imageUrl || FALLBACK} alt={restaurant.name} loading="lazy"
           onError={(e) => { e.currentTarget.src = FALLBACK; }} />
      <div className="card-body">
        <div className="row-between">
          <h3>{restaurant.name}</h3>
          <span className="rating">★ {Number(restaurant.rating).toFixed(1)}</span>
        </div>
        <p className="muted">{restaurant.cuisine} · {restaurant.city}</p>
        <p className="clamp">{restaurant.description}</p>
      </div>
    </Link>
  );
}

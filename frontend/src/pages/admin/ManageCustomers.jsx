import EmptyState from '../../components/EmptyState';
import ErrorMessage from '../../components/ErrorMessage';
import Loader from '../../components/Loader';
import useFetch from '../../hooks/useFetch';
import { adminService } from '../../services/adminService';

export default function ManageCustomers() {
  const { data, loading, error, reload } = useFetch(() => adminService.customers());
  if (loading) return <Loader />;
  if (error) return <ErrorMessage message={error} onRetry={reload} />;
  return (
    <>
      <h1>Customers</h1>
      <p className="muted">Customers who have ordered from your restaurants.</p>
      {data.length === 0 ? <EmptyState title="No customers yet" /> : (
        <div className="table-wrap">
          <table>
            <thead><tr><th>Name</th><th>Email</th><th>Phone</th><th>Address</th></tr></thead>
            <tbody>
              {data.map((c) => <tr key={c.id}><td>{c.fullName}</td><td>{c.email}</td><td>{c.phone || '—'}</td><td>{c.address || '—'}</td></tr>)}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

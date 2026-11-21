export const formatINR = (value) =>
  new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', minimumFractionDigits: 2 }).format(Number(value ?? 0));

export const formatDateTime = (iso) =>
  iso ? new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '';

export const STATUS_STEPS = ['PLACED', 'CONFIRMED', 'PREPARING', 'READY', 'DELIVERED'];

export const STATUS_LABEL = {
  PLACED: 'Placed', CONFIRMED: 'Confirmed', PREPARING: 'Preparing', READY: 'Ready',
  DELIVERED: 'Delivered', CANCELLED: 'Cancelled', REJECTED: 'Rejected',
};

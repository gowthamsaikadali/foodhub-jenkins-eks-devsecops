import { useCallback, useEffect, useRef, useState } from 'react';
import { getErrorMessage } from '../services/api';

/** Runs an async loader on mount (and when deps change) and tracks loading / error / data. */
export default function useFetch(loader, deps = []) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const loaderRef = useRef(loader);
  loaderRef.current = loader;

  const run = useCallback(async (silent) => {
    if (silent !== true) setLoading(true);
    setError('');
    try {
      setData(await loaderRef.current());
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }, []);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { run(); }, deps);

  return { data, setData, loading, error, reload: run };
}

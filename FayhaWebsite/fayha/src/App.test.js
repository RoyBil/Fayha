import { render, screen } from '@testing-library/react';
import App from './App';

test('renders the choir name in the navbar', () => {
  render(<App />);
  const brand = screen.getAllByText(/Fayha National Choir/i)[0];
  expect(brand).toBeInTheDocument();
});

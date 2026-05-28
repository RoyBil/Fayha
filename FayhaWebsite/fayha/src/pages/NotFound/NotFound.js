import React from 'react';
import { Link } from 'react-router-dom';
import './NotFound.css';

const NotFound = () => {
  return (
    <main className="not-found">
      <div className="container-narrow not-found__inner">
        <p className="not-found__eyebrow">404</p>
        <h1>Page not found</h1>
        <p className="not-found__text">
          The page you're looking for may have moved or does not exist.
        </p>
        <Link to="/" className="not-found__link">
          Return home →
        </Link>
      </div>
    </main>
  );
};

export default NotFound;

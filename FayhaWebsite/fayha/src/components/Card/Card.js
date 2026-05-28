import React from 'react';
import './Card.css';

const Card = ({ children, variant = 'default', className = '' }) => {
  return (
    <article className={`card card--${variant} ${className}`}>
      {children}
    </article>
  );
};

export default Card;

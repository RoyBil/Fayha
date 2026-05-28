import React from 'react';
import './PageHeader.css';

const PageHeader = ({ eyebrow, title, subtitle }) => {
  return (
    <header className="page-header">
      <div className="page-header__backdrop" aria-hidden="true"></div>
      <div className="page-header__inner container-narrow">
        {eyebrow && <p className="page-header__eyebrow">{eyebrow}</p>}
        <h1 className="page-header__title">{title}</h1>
        {subtitle && <p className="page-header__subtitle">{subtitle}</p>}
      </div>
    </header>
  );
};

export default PageHeader;

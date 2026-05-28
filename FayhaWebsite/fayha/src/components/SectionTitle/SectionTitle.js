import React from 'react';
import './SectionTitle.css';

const SectionTitle = ({ eyebrow, title, subtitle, align = 'center', light = false }) => {
  return (
    <div className={`section-title section-title--${align} ${light ? 'section-title--light' : ''}`}>
      {eyebrow && <p className="section-title__eyebrow">{eyebrow}</p>}
      <h2 className="section-title__title">{title}</h2>
      {align === 'center' && (
        <div className="section-title__divider">
          <span></span>
          <span className="section-title__dot">◆</span>
          <span></span>
        </div>
      )}
      {subtitle && <p className="section-title__subtitle">{subtitle}</p>}
    </div>
  );
};

export default SectionTitle;

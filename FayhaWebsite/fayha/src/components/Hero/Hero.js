import React from 'react';
import { Link } from 'react-router-dom';
import { heroContent } from '../../data/content';
import { performanceGrandHall } from '../../assets/images';
import './Hero.css';

const Hero = () => {
  return (
    <section className="hero">
      <div
        className="hero__backdrop"
        style={{ backgroundImage: `url(${performanceGrandHall})` }}
        aria-hidden="true"
      ></div>
      <div className="hero__overlay" aria-hidden="true"></div>

      <div className="hero__content container-narrow">
        <p className="hero__eyebrow fade-up">{heroContent.eyebrow}</p>
        <h1 className="hero__title fade-up" style={{ animationDelay: '120ms' }}>
          {heroContent.title}
        </h1>
        <div className="ornament fade-up" style={{ animationDelay: '200ms' }}>
          <span className="hero__ornament-icon">♪</span>
        </div>
        <p className="hero__subtitle fade-up" style={{ animationDelay: '280ms' }}>
          {heroContent.subtitle}
        </p>
        <div className="hero__actions fade-up" style={{ animationDelay: '380ms' }}>
          <Link to="/about" className="hero__cta hero__cta--primary">
            {heroContent.cta}
          </Link>
          <Link to="/music" className="hero__cta hero__cta--secondary">
            Listen to Our Music
          </Link>
        </div>
      </div>

      <div className="hero__scroll" aria-hidden="true">
        <span>Scroll</span>
        <div className="hero__scroll-line"></div>
      </div>
    </section>
  );
};

export default Hero;

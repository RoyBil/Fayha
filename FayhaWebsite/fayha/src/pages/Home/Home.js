import React from 'react';
import { Link } from 'react-router-dom';
import Hero from '../../components/Hero/Hero';
import SectionTitle from '../../components/SectionTitle/SectionTitle';
import Card from '../../components/Card/Card';
import { stats, story, notablePieces, siteInfo } from '../../data/content';
import {
  performanceGrandHall,
  ensembleArabicAttire,
  choirGroupOutdoor,
  sopranosEuropeTour,
  maestroConducting,
} from '../../assets/images';
import './Home.css';

const gallery = [
  { src: ensembleArabicAttire, caption: 'In traditional Arabic attire', span: 'tall' },
  { src: maestroConducting, caption: 'Maestro Barkev Taslakian', span: 'tall' },
  { src: performanceGrandHall, caption: 'On the grand stage', span: 'wide' },
  { src: sopranosEuropeTour, caption: 'On tour in Europe', span: 'square' },
  { src: choirGroupOutdoor, caption: 'Behind the scenes', span: 'square' },
];

const Home = () => {
  return (
    <main className="home">
      <Hero />

      {/* Introduction / Glimpse of story */}
      <section className="section home__intro">
        <div className="container-narrow">
          <SectionTitle
            eyebrow="Since 2003"
            title="Revolutionizing Arabic Choral Music"
            subtitle="A mixed Lebanese a cappella choir and the global reference for Arabic choral arrangements."
          />
          <div className="home__intro-body">
            <p className="home__intro-lead">{story.paragraphs[0]}</p>
          </div>
          <div className="home__intro-cta">
            <Link to="/about" className="home__link">
              Read our full story
              <span aria-hidden="true">→</span>
            </Link>
          </div>
        </div>
      </section>

      {/* Stats strip */}
      <section className="home__stats">
        <div className="container">
          <div className="home__stats-grid">
            {stats.map((stat) => (
              <div key={stat.label} className="home__stat">
                <div className="home__stat-value">{stat.value}</div>
                <div className="home__stat-label">{stat.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Featured music */}
      <section className="section section-alt">
        <div className="container">
          <SectionTitle
            eyebrow="Notable Pieces"
            title="Listen to Our Music"
            subtitle="Arabic classics reimagined through Arabic rhythms, microtonal maqams, and fine-tuned a cappella techniques."
          />
          <div className="home__music-grid">
            {notablePieces.map((piece) => (
              <Card key={piece.title} variant="elegant">
                <div className="home__music-piece">
                  <p className="home__music-arabic">{piece.title}</p>
                  <p className="home__music-translation">{piece.subtitle}</p>
                  <p className="home__music-composers">{piece.composers}</p>
                  <p className="home__music-desc">{piece.description}</p>
                  <a
                    href={piece.link}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="home__music-link"
                  >
                    ▸ Watch on YouTube
                  </a>
                </div>
              </Card>
            ))}
          </div>
          <div className="home__intro-cta">
            <Link to="/music" className="home__link">
              Explore our full repertoire
              <span aria-hidden="true">→</span>
            </Link>
          </div>
        </div>
      </section>

      {/* Gallery / Impressions */}
      <section className="section home__gallery-section">
        <div className="container">
          <SectionTitle
            eyebrow="Impressions"
            title="Moments from the Stage & Beyond"
            subtitle="Two decades of music, travel, and the people who make Fayha."
          />
          <div className="home__gallery">
            {gallery.map((item, idx) => (
              <figure
                key={idx}
                className={`home__gallery-item home__gallery-item--${item.span}`}
              >
                <img src={item.src} alt={item.caption} loading="lazy" />
                <figcaption>{item.caption}</figcaption>
              </figure>
            ))}
          </div>
        </div>
      </section>

      {/* Locations banner */}
      <section className="home__locations">
        <div className="container-narrow">
          <p className="home__locations-eyebrow">The National Choir of Lebanon</p>
          <h2 className="home__locations-title">
            {siteInfo.locations.join(' · ')}
          </h2>
          <p className="home__locations-sub">
            Four branches across Lebanon. One voice for the region.
          </p>
        </div>
      </section>

      {/* Call to action */}
      <section className="section home__cta-section">
        <div className="container-narrow home__cta-inner">
          <h2>Join us in preserving and sharing Arabic musical heritage.</h2>
          <p>
            Follow our performances, discover our social projects, or connect
            with us directly.
          </p>
          <div className="home__cta-buttons">
            <Link to="/projects" className="home__button home__button--primary">
              Our Social Projects
            </Link>
            <Link to="/contact" className="home__button home__button--secondary">
              Get in Touch
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
};

export default Home;

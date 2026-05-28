import React from 'react';
import PageHeader from '../../components/PageHeader/PageHeader';
import SectionTitle from '../../components/SectionTitle/SectionTitle';
import Card from '../../components/Card/Card';
import ImageBanner from '../../components/ImageBanner/ImageBanner';
import { notablePieces, trainedChoirs } from '../../data/content';
import { performanceGrandHall } from '../../assets/images';
import './Music.css';

const Music = () => {
  return (
    <main className="music">
      <PageHeader
        eyebrow="Our Repertoire"
        title="Our Music"
        subtitle="A diverse repertoire of Arabic classics — presented a cappella, without instrumental accompaniment."
      />

      <section className="section">
        <div className="container-narrow">
          <ImageBanner
            image={performanceGrandHall}
            caption="Live performance, full ensemble — no instruments, only voices."
            height="large"
          />
          <div className="music__intro">
            <p>
              The arrangements are commissioned by the choir from several
              musicians, most notably Dr. Edward Torikian, Professor of Music at
              USEK. Despite its young age, the Arabic a cappella artform has
              quickly matured — garnering an international audience.
            </p>
            <p>
              Our experimentation with <strong>Arabic rhythms</strong>,{' '}
              <strong>microtonal maqams</strong>, and unique linguistic textures
              — combined with songs of resilience, identity, and prayer — makes
              for a novel, moving, and exciting sonic experience. To date, the
              choir has been invited to perform in more than{' '}
              <strong>20 countries</strong>, from China to Canada.
            </p>
          </div>
        </div>
      </section>

      {/* Notable Pieces */}
      <section className="section section-alt">
        <div className="container">
          <SectionTitle
            eyebrow="Featured Works"
            title="Notable Pieces"
            subtitle="Signature performances that capture our artistic voice."
          />

          <div className="music__pieces">
            {notablePieces.map((piece, idx) => (
              <Card
                key={piece.title}
                variant="elegant"
                className="music__piece-card"
              >
                <div className="music__piece-number">
                  {String(idx + 1).padStart(2, '0')}
                </div>
                <h3 className="music__piece-title">{piece.title}</h3>
                {piece.subtitle && (
                  <p className="music__piece-translation">{piece.subtitle}</p>
                )}
                <div className="music__piece-divider"></div>
                {piece.composers && (
                  <p className="music__piece-composers">{piece.composers}</p>
                )}
                {piece.description && (
                  <p className="music__piece-desc">{piece.description}</p>
                )}
                {piece.link && (
                  <a
                    href={piece.link}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="music__piece-button"
                  >
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M8 5v14l11-7z" />
                    </svg>
                    Watch Performance
                  </a>
                )}
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* Spreading the artform */}
      <section className="section section-dark">
        <div className="container">
          <SectionTitle
            eyebrow="Spreading the Artform"
            title="Training the Next Generation"
            subtitle="To ensure the sustenance of Arabic a cappella, we train conductors across the Arab region — many of whom have founded their own choirs."
            light
          />
          <div className="music__choirs">
            {trainedChoirs.map((choir) => (
              <a
                key={choir.name}
                href={choir.link}
                target="_blank"
                rel="noopener noreferrer"
                className="music__choir-card"
              >
                <div className="music__choir-head">
                  <h4>{choir.name}</h4>
                  <span className="music__choir-period">{choir.period}</span>
                </div>
                <p className="music__choir-location">{choir.location}</p>
                <p className="music__choir-conductor">
                  <span>Conductor:</span> {choir.conductor}
                </p>
                <p className="music__choir-note">{choir.note}</p>
                <span className="music__choir-link">
                  View on Instagram →
                </span>
              </a>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
};

export default Music;

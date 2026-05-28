import React from 'react';
import PageHeader from '../../components/PageHeader/PageHeader';
import SectionTitle from '../../components/SectionTitle/SectionTitle';
import { principalConductor, assistantConductors } from '../../data/content';
import {
  maestroConducting,
  fatmaRachaShehadeh,
  mahmoudMawass,
  oussamaCharafeddine,
} from '../../assets/images';
import './Conductors.css';

const images = {
  maestroConducting,
  fatmaRachaShehadeh,
  mahmoudMawass,
  oussamaCharafeddine,
};

const Conductors = () => {
  return (
    <main className="conductors">
      <PageHeader
        eyebrow="The Team"
        title="Our Conductors"
        subtitle="From the founding maestro to a new generation — the voices shaping Fayha's sound."
      />

      {/* Principal Conductor */}
      <section className="section">
        <div className="container">
          <SectionTitle
            eyebrow="Principal Conductor"
            title="Maestro Barkev Taslakian"
            subtitle="Founder of Fayha National Choir — leading the ensemble since 2003."
          />

          <article className="conductors__card conductors__card--maestro">
            <div className="conductors__portrait">
              <img
                src={images[principalConductor.imageKey]}
                alt={principalConductor.name}
              />
              <span className="conductors__tag">{principalConductor.name}</span>
            </div>
            <div className="conductors__body">
              <h3 className="conductors__name">{principalConductor.name}</h3>
              <p className="conductors__meta">{principalConductor.role}</p>
              {principalConductor.bio.map((p, pidx) => (
                <p key={pidx} className="conductors__paragraph">
                  {p}
                </p>
              ))}
            </div>
          </article>
        </div>
      </section>

      {/* Assistant Conductors */}
      <section className="section section-alt">
        <div className="container">
          <SectionTitle
            eyebrow="Next Generation"
            title="Assistant Conductors"
            subtitle="Trained under Maestro Taslakian — leading choirs across Lebanon and beyond."
          />

          <div className="conductors__list">
            {assistantConductors.map((c, idx) => (
              <article
                key={c.slug}
                className={`conductors__card ${idx % 2 === 1 ? 'conductors__card--reverse' : ''}`}
              >
                <div className="conductors__portrait">
                  <img src={images[c.imageKey]} alt={c.name} />
                  <span className="conductors__tag">{c.name}</span>
                </div>
                <div className="conductors__body">
                  <h3 className="conductors__name">{c.name}</h3>
                  <p className="conductors__meta">{c.birth}</p>
                  {c.bio.map((p, pidx) => (
                    <p key={pidx} className="conductors__paragraph">
                      {p}
                    </p>
                  ))}
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
};

export default Conductors;

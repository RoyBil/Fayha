import React from 'react';
import PageHeader from '../../components/PageHeader/PageHeader';
import SectionTitle from '../../components/SectionTitle/SectionTitle';
import ImageBanner from '../../components/ImageBanner/ImageBanner';
import { affiliations } from '../../data/content';
import { sopranosEuropeTour } from '../../assets/images';
import './Affiliations.css';

const Affiliations = () => {
  return (
    <main className="affiliations">
      <PageHeader
        eyebrow="Global Network"
        title="Our Affiliations"
        subtitle="Intercultural dialogue and growth through music, built on a firm belief in the power of the collective."
      />

      <section className="section">
        <div className="container-narrow">
          <ImageBanner
            image={sopranosEuropeTour}
            caption="On tour — ambassadors of Arabic a cappella across the globe."
            height="medium"
          />
          <div className="affiliations__intro">
            <p>
              Fayha National Choir is a <strong>co-founder of the Arab Choral
              Network</strong>, contributing to the development of a structured
              choral culture across the Arab world. The choir has organized major
              international cultural events, notably the{' '}
              <strong>Lebanese International Choir Festival</strong> in 2015 and
              2017 — featuring more than 1,000 participants from 8 countries.
            </p>
          </div>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <SectionTitle
            eyebrow="Partners & Members"
            title="International Bodies"
            subtitle="Active networking and collaborative projects with global choral organizations."
          />
          <div className="affiliations__grid">
            {affiliations.map((item) => (
              <article key={item.name} className="affiliations__card">
                <div className="affiliations__card-role">{item.role}</div>
                <h3 className="affiliations__card-name">{item.name}</h3>
                <div className="affiliations__card-divider"></div>
                <p className="affiliations__card-desc">{item.description}</p>
                {item.link && (
                  <a
                    href={item.link}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="affiliations__card-link"
                  >
                    Visit website →
                  </a>
                )}
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="section affiliations__tour">
        <div className="container-narrow">
          <div className="affiliations__tour-inner">
            <p className="affiliations__tour-eyebrow">Most Recent</p>
            <h2>European Choral Association · Study Tour 2025</h2>
            <p className="affiliations__tour-body">
              In collaboration with the European Choral Association, Fayha
              organized a study tour to Lebanon in 2025 — welcoming conductors
              and choral leaders to engage in artistic exchange, workshops on
              Arabic music, and a culturally immersive experience.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
};

export default Affiliations;

import React from 'react';
import PageHeader from '../../components/PageHeader/PageHeader';
import SectionTitle from '../../components/SectionTitle/SectionTitle';
import ImageBanner from '../../components/ImageBanner/ImageBanner';
import { socialProjects } from '../../data/content';
import { choirGroupOutdoor } from '../../assets/images';
import './Projects.css';

const Projects = () => {
  return (
    <main className="projects">
      <PageHeader
        eyebrow="Music for Social Change"
        title="Our Social Projects"
        subtitle="Promoting social cohesion and building peace through collective singing."
      />

      <section className="section">
        <div className="container-narrow">
          <ImageBanner
            image={choirGroupOutdoor}
            caption="Our choir family — Fayha, beyond the stage."
            height="medium"
          />
          <div className="projects__intro">
            <p>
              By 2009, after six years in Tripoli, the choir had spontaneously —
              yet unintentionally — become a microcosm of the city: a melting
              pot of different religions, cultures, nationalities, and classes.
              In stark contrast to a city rife with conflict, the choir was a
              safe space of mutual growth and understanding.
            </p>
            <p>
              In an attempt to expand that peace beyond rehearsals and into
              everyday life, our team started taking on social projects aimed at
              promoting social cohesion through collective singing. In
              recognition of this work, Fayha was awarded the{' '}
              <strong>International Music Council's Music Rights Award</strong>{' '}
              in 2015.
            </p>
          </div>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <SectionTitle
            eyebrow="Initiatives"
            title="Two Decades of Impact"
            subtitle="A selection of social projects we have led across Lebanon."
          />
          <div className="projects__list">
            {socialProjects.map((project, idx) => (
              <article key={project.name} className="projects__card">
                <div className="projects__card-index">{String(idx + 1).padStart(2, '0')}</div>
                <div className="projects__card-body">
                  <div className="projects__card-head">
                    <h3>{project.name}</h3>
                    <span className="projects__card-period">{project.period}</span>
                  </div>
                  <p className="projects__card-partner">
                    <span>In partnership with:</span> {project.partner}
                  </p>
                  <p className="projects__card-desc">{project.description}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* Impact banner */}
      <section className="projects__impact">
        <div className="container">
          <div className="projects__impact-grid">
            <div className="projects__impact-item">
              <div className="projects__impact-num">10,000+</div>
              <div className="projects__impact-label">Students Reached</div>
            </div>
            <div className="projects__impact-item">
              <div className="projects__impact-num">4</div>
              <div className="projects__impact-label">Lebanese Provinces</div>
            </div>
            <div className="projects__impact-item">
              <div className="projects__impact-num">15</div>
              <div className="projects__impact-label">Conductors in Training</div>
            </div>
            <div className="projects__impact-item">
              <div className="projects__impact-num">2015</div>
              <div className="projects__impact-label">IMC Music Rights Award</div>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
};

export default Projects;

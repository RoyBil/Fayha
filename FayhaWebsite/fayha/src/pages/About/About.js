import React from 'react';
import PageHeader from '../../components/PageHeader/PageHeader';
import SectionTitle from '../../components/SectionTitle/SectionTitle';
import ImageBanner from '../../components/ImageBanner/ImageBanner';
import { story, siteInfo, achievements } from '../../data/content';
import {
  ensembleArabicAttire,
  maestroConducting,
  choirGroupOutdoor,
} from '../../assets/images';
import './About.css';

const About = () => {
  return (
    <main className="about">
      <PageHeader
        eyebrow={`Est. ${siteInfo.founded}`}
        title="Our Story"
        subtitle="From the orange groves of Tripoli to the stages of the world."
      />

      <section className="section">
        <div className="container-narrow">
          <ImageBanner
            image={ensembleArabicAttire}
            caption="The choir in traditional Arabic attire — gold on black."
            height="large"
          />
          <div className="about__story">
            {story.paragraphs.map((p, idx) => (
              <p key={idx} className="about__paragraph">
                {idx === 0 && <span className="about__dropcap">F</span>}
                {idx === 0 ? p.slice(1) : p}
              </p>
            ))}
          </div>
        </div>
      </section>

      {/* Founder / Maestro */}
      <section className="section section-alt">
        <div className="container">
          <SectionTitle
            eyebrow="Our Founder"
            title="Maestro Barkev Taslakian"
            subtitle="Founder, Artistic Director, and Principal Conductor."
          />
          <div className="about__maestro">
            <div className="about__maestro-portrait">
              <img
                src={maestroConducting}
                alt="Maestro Barkev Taslakian conducting Fayha National Choir"
              />
              <span className="about__maestro-tag">Barkev Taslakian</span>
            </div>
            <div className="about__maestro-body">
              <p>
                Maestro Barkev Taslakian founded Fayha National Choir in 2003
                and continues to lead it as its principal conductor. Widely
                regarded as a visionary in Arabic choral music, his work has
                helped establish Arabic a cappella as a serious global art form
                and has built a vast repertoire now used by choirs worldwide.
              </p>
              <p>
                Prior to founding Fayha, he conducted several choirs in Lebanon
                and Armenia. Under his leadership, Fayha has reached
                international acclaim and performed across more than 30
                countries.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Achievements Timeline */}
      <section className="section">
        <div className="container">
          <SectionTitle
            eyebrow="Recognition"
            title="Achievements"
            subtitle="Two decades of international acclaim and artistic milestones."
          />
          <ol className="about__timeline">
            {achievements
              .slice()
              .sort((a, b) => b.year - a.year)
              .map((a, idx) => (
                <li key={idx} className="about__timeline-item">
                  <div className="about__timeline-year">{a.year}</div>
                  <div className="about__timeline-marker" aria-hidden="true"></div>
                  <div className="about__timeline-content">
                    <h4>{a.title}</h4>
                    <p>{a.event}</p>
                  </div>
                </li>
              ))}
          </ol>
        </div>
      </section>

      {/* Family banner */}
      <section className="section section-alt">
        <div className="container-narrow">
          <ImageBanner
            image={choirGroupOutdoor}
            caption="The choir family — one voice across religions, nationalities and backgrounds."
            height="medium"
          />
        </div>
      </section>

      {/* Quote banner */}
      <section className="about__quote">
        <div className="container-narrow">
          <blockquote>
            <p>
              "The choir is a product of Lebanon's rich social fabric — proudly
              coexisting and thriving across religions, nationalities and
              backgrounds."
            </p>
          </blockquote>
        </div>
      </section>
    </main>
  );
};

export default About;

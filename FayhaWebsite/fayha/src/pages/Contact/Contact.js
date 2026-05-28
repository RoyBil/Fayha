import React, { useState } from 'react';
import PageHeader from '../../components/PageHeader/PageHeader';
import { siteInfo, directors } from '../../data/content';
import './Contact.css';

const Contact = () => {
  const [form, setForm] = useState({ name: '', email: '', subject: '', message: '' });
  const [sent, setSent] = useState(false);

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    const localPart = 'manager';
    const domain = 'fayhanationalchoir.com';
    const to = `${localPart}@${domain}`;
    const subject = form.subject || `Website enquiry from ${form.name || 'visitor'}`;
    const body = `Name: ${form.name}\nEmail: ${form.email}\n\n${form.message}`;
    window.location.href = `mailto:${to}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    setSent(true);
  };

  return (
    <main className="contact">
      <PageHeader
        eyebrow="Get in Touch"
        title="Contact Us"
        subtitle="For bookings, collaborations, or general enquiries — we would love to hear from you."
      />

      <section className="section">
        <div className="container">
          <div className="contact__grid">
            {/* Left: Directors + Branches */}
            <div className="contact__col">
              <h3 className="contact__col-title">Directors</h3>
              <div className="contact__directors">
                {directors.map((d) => (
                  <div key={d.name} className="contact__director">
                    <h4>{d.name}</h4>
                    <p className="contact__director-role">{d.role}</p>
                    {d.phone && (
                      <a
                        href={`tel:${d.phone.replace(/\s/g, '')}`}
                        className="contact__director-phone"
                      >
                        {d.phone}
                      </a>
                    )}
                  </div>
                ))}
              </div>

              <div className="contact__locations">
                <h3 className="contact__col-title">Our Branches</h3>
                <div className="contact__locations-grid">
                  {siteInfo.locations.map((loc) => (
                    <div key={loc} className="contact__location">
                      <span className="contact__location-pin">◆</span>
                      {loc}
                    </div>
                  ))}
                </div>
              </div>

              <div className="contact__locations">
                <h3 className="contact__col-title">Follow</h3>
                <a
                  href={siteInfo.instagram}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="contact__instagram"
                >
                  {siteInfo.instagramHandle}
                </a>
              </div>
            </div>

            {/* Right: Contact form */}
            <div className="contact__col contact__col--info">
              <div className="contact__form-card">
                <h3 className="contact__col-title">Send Us a Message</h3>
                <p className="contact__form-intro">
                  Fill in the form below and your email client will open with
                  your message ready to send.
                </p>

                <form onSubmit={handleSubmit} className="contact__form">
                  <div className="contact__form-row">
                    <label htmlFor="contact-name">Name</label>
                    <input
                      id="contact-name"
                      name="name"
                      type="text"
                      required
                      value={form.name}
                      onChange={handleChange}
                      placeholder="Your full name"
                    />
                  </div>

                  <div className="contact__form-row">
                    <label htmlFor="contact-email">Email</label>
                    <input
                      id="contact-email"
                      name="email"
                      type="email"
                      required
                      value={form.email}
                      onChange={handleChange}
                      placeholder="you@example.com"
                    />
                  </div>

                  <div className="contact__form-row">
                    <label htmlFor="contact-subject">Subject</label>
                    <input
                      id="contact-subject"
                      name="subject"
                      type="text"
                      value={form.subject}
                      onChange={handleChange}
                      placeholder="Booking, collaboration, press, etc."
                    />
                  </div>

                  <div className="contact__form-row">
                    <label htmlFor="contact-message">Message</label>
                    <textarea
                      id="contact-message"
                      name="message"
                      required
                      rows="5"
                      value={form.message}
                      onChange={handleChange}
                      placeholder="Tell us a little about your enquiry..."
                    />
                  </div>

                  <button type="submit" className="contact__form-submit">
                    Send Message
                  </button>

                  {sent && (
                    <p className="contact__form-sent">
                      Your email client should have opened — finish and send
                      your message from there.
                    </p>
                  )}
                </form>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="contact__cta">
        <div className="container-narrow">
          <p className="contact__cta-arabic">{siteInfo.arabicName}</p>
          <h2>Music is the language of coexistence.</h2>
          <p className="contact__cta-text">
            Two decades of building peace and artistic excellence through
            Arabic choral music.
          </p>
        </div>
      </section>
    </main>
  );
};

export default Contact;

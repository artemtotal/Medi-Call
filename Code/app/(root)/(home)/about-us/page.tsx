export default function AboutUsPage() {
  return (
    <main className="min-h-screen space-y-8 bg-gray-900 p-8 text-white">
      {/* Hauptüberschrift und Einführung */}
      <section>
        <h1 className="mb-4 text-4xl font-bold">About us</h1>
        <p>
          Medi‑Call ist eine innovative Telemedizin-Plattform, die Patienten und
          medizinische Fachkräfte über sichere, hochwertige Videoanrufe miteinander
          verbindet. Unser Ziel ist es, eine schnelle und effektive Versorgung zu
          ermöglichen – jederzeit und überall.
        </p>
      </section>

      {/* Workflow aus Sicht des Arztes */}
      <section>
        <h2 className="mb-2 text-3xl font-semibold">Vorgehensweise für Ärzte</h2>
        <ol className="ml-6 list-decimal">
          <li>Der Arzt registriert sich über Clerk und loggt sich in sein Dashboard ein.</li>
          <li>Er pflegt sein Profil und legt seine verfügbaren Sprechzeiten fest.</li>
          <li>Termin-Anfragen werden automatisch in seinem Dashboard angezeigt.</li>
          <li>Nach Überprüfung startet er den geplanten Videoanruf.</li>
          <li>Abschließend dokumentiert er den Termin und schließt ihn ab.</li>
        </ol>
      </section>

      {/* Workflow aus Sicht des Patienten */}
      <section>
        <h2 className="mb-2 text-3xl font-semibold">Vorgehensweise für Patienten</h2>
        <ol className="ml-6 list-decimal">
          <li>Der Patient registriert sich über Clerk und meldet sich in seinem Konto an.</li>
          <li>Er wählt die Option &quot;Termin vereinbaren&quot; und gibt sein Anliegen ein.</li>
          <li>Er wählt aus den verfügbaren Zeiten einen passenden Termin aus.</li>
          <li>Nach Bestätigung erhält er eine Benachrichtigung mit einem Meeting-Link.</li>
          <li>Zum vereinbarten Zeitpunkt klickt er auf den Link, prüft seine Einstellungen und nimmt am Videoanruf teil.</li>
        </ol>
      </section>

      {/* Link zum Anleitung-Dokument */}
      <section>
        <p className="mt-4">
          <a
            href="https://docs.google.com/document/d/1FOLLmYbDMmgYQdXgFPLiWwGUg1VCZGlQ93LcGJP05v0/edit?usp=sharing"
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-400 underline"
          >
            Anleitung lesen
          </a>
        </p>
      </section>
    </main>
  );
}

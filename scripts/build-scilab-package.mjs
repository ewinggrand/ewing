import { readFile, writeFile, mkdir, readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { zipSync, strToU8 } from "fflate";
import katex from "katex";

// LaTeX is compiled once when packaging. The Scilab application itself has no
// JavaScript/Node dependency: its offline HTML report embeds native MathML.
const formulas = [
  ["axes-pitch", String.raw`\beta=\frac{2\pi y}{Q},\quad\varphi_{c,-}=\varphi_{c,+}+\varepsilon_c\beta,\quad\gamma_c=\frac{\varphi_{c,+}+\varphi_{c,-}}2`],
  ["axes-oriented", String.raw`\alpha_c=-\frac{\arg C_{c,p}}p,\quad\alpha_a=-\frac{\arg C_{a,p}}p,\quad\Delta\alpha_{c,\mathrm{el}}=\operatorname{wrap}_{[-\pi,\pi)}\{p(\alpha_c-\alpha_a)\}`],
  ["coil-difference", String.raw`D_{c,k}=e^{-jk\varphi_{c,+}}-e^{-jk\varphi_{c,-}}=2j\varepsilon_c\sin(k\beta/2)e^{-jk\gamma_c}`],
  ["coil-factor", String.raw`S_k=\sin(k\beta/2),\quad\xi_k=\frac{S_k}{k},\quad C_{c,k}=\varepsilon_c\xi_ke^{-jk\gamma_c}`],
  ["group-factor", String.raw`G_{g,k}=\frac1{N_{c,g}}\sum_{c\in g}\varepsilon_c e^{-jk(\gamma_c-\alpha_g)}`],
  ["phase-factor", String.raw`H_{a,k}=\sum_{g\in a}\frac{N_{c,g}}{N_{c,a}}G_{g,k}e^{-jk(\alpha_g-\alpha_a)},\quad k_{w,a,k}=|S_kH_{a,k}|`],
  ["phase-spectrum", String.raw`C_{a,k}=\frac{N_{c,a}}kS_kH_{a,k}e^{-jk\alpha_a},\quad k=p\nu`],
  ["winding-function", String.raw`w_a(\varphi)=\frac2\pi\sum_{k=1}^\infty\operatorname{Re}\{C_{a,k}e^{jk\varphi}\},\quad\int_0^{2\pi}w_a\,d\varphi=0,\quad N_a=nw_a`],
  ["mmf-field", String.raw`\Theta(\varphi)=\sum_{a\in\{A,B,C\}}N_a(\varphi)i_a,\quad B(\varphi)=\frac{\mu_0}{\delta_{\mathrm{eff}}}\Theta(\varphi)`],
  ["pair-field", String.raw`B_R(x-x_R)=\frac{2\mu_0n_Ri_R}{\pi\delta}\sum_{\nu=1}^\infty\frac{\sin(\nu\pi w_R/(2\tau_p))}{\nu}\cos\!\left(\frac{\nu\pi(x-x_R)}{\tau_p}\right)`],
  ["pair-integral", String.raw`\int_{-w_S/2}^{w_S/2}\cos\!\left(\frac{\nu\pi(x-x_R)}{\tau_p}\right)dx=\frac{2\tau_p}{\nu\pi}\sin\!\left(\frac{\nu\pi w_S}{2\tau_p}\right)\cos\!\left(\frac{\nu\pi x_R}{\tau_p}\right)`],
  ["pair-xi", String.raw`\xi_{S,\nu}=\frac1\nu\sin\!\left(\frac{\nu\pi w_S}{2\tau_p}\right),\quad\xi_{R,\nu}=\frac1\nu\sin\!\left(\frac{\nu\pi w_R}{2\tau_p}\right)`],
  ["pair-linkage", String.raw`\Psi_{SR}=\frac{4\mu_0\tau_p\ell_{\mathrm{Fe}}n_Sn_Ri_R}{\pi^2\delta}\sum_{\nu=1}^\infty\xi_{S,\nu}\xi_{R,\nu}\cos\!\left(\frac{\nu\pi x_R}{\tau_p}\right)`],
  ["stator-linkage", String.raw`\Psi_a=r\ell_{\mathrm{Fe}}\int_0^{2\pi}N_aB\,d\varphi=\sum_bL_{ab}i_b,\quad\tau_p=\frac{\pi r}p`],
  ["pair-inductance", String.raw`L_{SR}=\frac{\Psi_{SR}}{i_R}=\frac{4\mu_0\tau_p\ell_{\mathrm{Fe}}n_Sn_R}{\pi^2\delta}\sum_{\nu=1}^\infty\xi_{S,\nu}\xi_{R,\nu}\cos(\nu\pi x_R/\tau_p)`],
  ["self-inductance", String.raw`L_{SS}=\frac{4\mu_0\tau_p\ell_{\mathrm{Fe}}n_S^2}{\pi^2\delta}\sum_{\nu=1}^\infty\xi_{S,\nu}^2`],
  ["gram-inductance", String.raw`L_{ab}=\frac{\mu_0r\ell_{\mathrm{Fe}}n^2}{\delta_{\mathrm{eff}}}\int_0^{2\pi}w_aw_b\,d\varphi=\frac{\mu_0r\ell_{\mathrm{Fe}}n^2}{\delta_{\mathrm{eff}}}\sum_jw_{a,j}w_{b,j}\Delta\varphi_j`],
  ["fourier-inductance", String.raw`L_{ab}=\frac{4\mu_0r\ell_{\mathrm{Fe}}n^2}{\pi\delta_{\mathrm{eff}}}\sum_{k=1}^\infty\operatorname{Re}\{C_{a,k}\overline{C_{b,k}}\},\quad L_{aa}=\frac{4\mu_0r\ell_{\mathrm{Fe}}n^2}{\pi\delta_{\mathrm{eff}}}\sum_{k=1}^\infty|C_{a,k}|^2`],
  ["matrix-linkage", String.raw`\begin{bmatrix}\Psi_A\\\Psi_B\\\Psi_C\end{bmatrix}=\begin{bmatrix}L_{AA}&L_{AB}&L_{AC}\\L_{BA}&L_{BB}&L_{BC}\\L_{CA}&L_{CB}&L_{CC}\end{bmatrix}\begin{bmatrix}i_A\\i_B\\i_C\end{bmatrix}`],
  ["differential", String.raw`L_{ab}=\frac{\partial\Psi_a}{\partial i_b},\quad L_{aa}=\left.\frac{\Psi_a}{i_a}\right|_{i_{b\ne a}=0}`],
  ["energy", String.raw`W_{\mathrm{mag}}=\frac12\boldsymbol i^{\mathsf T}\mathbf L\boldsymbol i=\frac{\mu_0r\ell_{\mathrm{Fe}}}{2\delta_{\mathrm{eff}}}\int_0^{2\pi}\Theta^2\,d\varphi\ge0`],
];
const root = new URL("../scilab/", import.meta.url);
await mkdir(new URL("resources/", root), { recursive: true });
const rows = formulas.map(([key, latex]) => [key, latex, katex.renderToString(latex, { output: "mathml", displayMode: true, throwOnError: true, trust: false })].join("\t"));
await writeFile(new URL("resources/equations.tsv", root), rows.join("\n") + "\n");
const entries = {};
async function collect(directory, prefix = "") {
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
    if (entry.name === "exports" || entry.name.startsWith(".")) continue;
    const relative = `${prefix}${entry.name}`;
    const location = new URL(entry.name + (entry.isDirectory() ? "/" : ""), directory);
    if (entry.isDirectory()) await collect(location, `${relative}/`);
    else entries[`wicklungsatelier-scilab/${relative}`] = new Uint8Array(await readFile(location));
  }
}
await collect(root);
entries["LESEN.txt"] = strToU8("Wicklungsatelier fuer Scilab · Version 1.0\n\nScilab Desktop 2024.1 oder neuer empfohlen.\nZIP vollstaendig entpacken und Scilab starten.\nDatei > Ausfuehren: wicklungsatelier-scilab/start.sce auswaehlen.\nKeine ATOMS-Toolbox, kein Node.js und keine Internetverbindung erforderlich.\nAnleitung und mathematisches Modell: wicklungsatelier-scilab/README.md.\nDie voreingestellten Maschinenabmessungen sind Beispielwerte.\n");
const zip = zipSync(entries, { level: 9, mtime: new Date("2020-01-01T00:00:00Z") });
const destination = new URL("../downloads/wicklungsatelier-scilab.zip", import.meta.url);
await writeFile(destination, zip);
console.log(`Scilab package: ${fileURLToPath(destination)} (${zip.length} bytes, ${Object.keys(entries).length} files, ${formulas.length} offline MathML formulas).`);

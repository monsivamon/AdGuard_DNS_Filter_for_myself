# AdGuard DNS Filter for Personal Use

This is a personal AdGuard DNS filter list, mainly created for learning and experimentation.
I'm still learning GitHub and filter creation, so things might not be perfect — thanks for your understanding!

---

## 📌 Important Notes

- This filter is intended for testing and personal use only.
- I do not guarantee its effectiveness in blocking ads, trackers, or harmful content.
- Use at your own risk — I'm not responsible if anything breaks or goes wrong.

---

## 🔧 Filter Creation Process

- The filter list is first generated using the [AdGuardTeam/HostlistCompiler](https://github.com/AdguardTeam/HostlistCompiler).
- Then, shell scripts are used to clean and customize the filter list.
- You can view the original unprocessed filter list [here](https://monsivamon.github.io/AdGuard_DNS_Filter_for_myself/Filters/generated_org.txt).
- These customizations include filtering out non-existent domains by checking them with [massdns](https://github.com/blechschmidt/massdns).
- Please note that these modifications are unofficial and might reduce the effectiveness of the original filter[AdGuardTeam/AdGuardSDNSFilter](https://github.com/AdguardTeam/AdGuardSDNSFilter).

---

## 🔗 How to Use This Filter

To use this filter in AdGuard (AdGuard Home, AdGuard DNS, etc.), add the following URL to your custom DNS filter list:

https://monsivamon.github.io/AdGuard_DNS_Filter_for_myself/Filters/main_filter.txt

To use this filter in AdAway, add the following URL to your custom host filter list:

https://monsivamon.github.io/AdGuard_DNS_Filter_for_myself/Filters/converted_for_adaway.txt

⚠️ To reduce false positives, this version is less aggressive than the AdGuard DNS version and may have lower blocking accuracy.

---

## 🔄 Update Policy

- This filter is automatically updated every 8 hours using GitHub Actions.
- Each update pulls the latest source rules, verifies domains using massdns, and rebuilds the list.
- Manual edits or updates may also be made at any time during testing or maintenance.

---

## 📝 Credits & Source Projects

This filter includes references, ideas, and in some cases direct rules from the following GPL-licensed projects.  
They have been invaluable for learning and building this filter list.

- [AdGuardTeam/HostlistCompiler](https://github.com/AdguardTeam/HostlistCompiler) – A tool to automatically generate DNS-based filters for blocking ads and trackers.
- [AdGuardTeam/AdGuardSDNSFilter](https://github.com/AdguardTeam/AdGuardSDNSFilter) – DNS-based blocking of ads and tracking.
- [uBlockOrigin/uAssets](https://github.com/uBlockOrigin/uAssets) – Official filter list from the uBlock Origin team.
- [blechschmidt/massdns](https://github.com/blechschmidt/massdns) – High-performance DNS resolver used here to verify domains.
- [curbengh/phishing-filter](https://github.com/curbengh/phishing-filter) – Blocks sites that try to steal your info by pretending to be legit.
- [curbengh/urlhaus-filter](https://github.com/curbengh/urlhaus-filter) – Blocks domains and URLs associated with malware.
- [Yuki2718/adblock2](https://github.com/Yuki2718/adblock2) – AdGuard/uBlock-compatible filter tailored for Japanese websites.
- [host2ch](https://note.com/hosts2ch) - Host filters for smartphone apps and websites, freely distributed in Japan.
- [publicsuffix.org](https://publicsuffix.org/) – Public Suffix List, used for accurate domain parsing and filtering.
- [DNSet/public-dns](https://github.com/DNSet/public-dns) – Public DNS data referenced for domain filtering.

I deeply respect the original authors and thank them for their contributions.

---

## ⚖️ License

This project includes components from other repositories licensed under the GNU General Public License v3.0.  
Therefore, this repository is also licensed under the GPL v3.
For full terms, please refer to the [LICENSE](./LICENSE) file.

---

Thank you for visiting this repository!  
I hope it may be helpful or inspiring in your own filtering efforts.


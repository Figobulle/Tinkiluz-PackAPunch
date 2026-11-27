# Tinkiluz-PackAPunch

Mod Brotato (Godot 3.6). Dépôt GitHub : https://github.com/Figobulle/Tinkiluz-PackAPunch

## Workflow Git (obligatoire)

- **Jamais de travail directement sur `main`.** Chaque nouvelle fonctionnalité, correction ou modification se fait sur sa propre branche (créée par l'utilisateur ou par Claude), par ex. `feature/nom-court` ou `fix/nom-court`.
- On développe et on teste sur la branche. Quand c'est bon, on ouvre une **pull request** vers `main`.
- **Claude ne push rien, n'ouvre aucune PR et ne merge rien sans l'accord explicite de l'utilisateur** dans la conversation. Les commits locaux sur la branche sont autorisés.
- Pas de force-push, pas de réécriture d'historique sur `main`.

## Notes

- Git et GitHub CLI sont à `C:\Program Files\Git\cmd\git.exe` et `C:\Program Files\GitHub CLI\gh.exe` (un shell ouvert avant leur installation peut ne pas les avoir dans le PATH).
- Commits signés avec l'adresse noreply GitHub (déjà configurée dans le dépôt).

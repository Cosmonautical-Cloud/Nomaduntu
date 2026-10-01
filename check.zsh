#! /bin/zsh

# Run Nomaduntu in check mode
ansible-playbook playbooks/deploy.yml --check --diff

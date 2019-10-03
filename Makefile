.PHONY: deploy awardRestart

deploy:
	ethereum-playbook -g ropsten deploy-lottery-token

deploy:
	ethereum-playbook -g ropsten award-winner-and-restart

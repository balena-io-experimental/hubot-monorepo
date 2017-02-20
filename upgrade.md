# Upgrade script
## About
A simple list of actions and notes for sqweelygig to attempt to ensure a consistent upgrade experience.
## Do
1. Advertise the changes
	1. Visit Heroku and note the latest commit deployed to production
	2. Compare this with the current state
	3. Check the user-perspective summary in changelog
	4. Put the user-perspective summary of the changes into devops
	5. Offer a detailed summary of the changes
2. Test the changes
	1. Check setup.md for any modifications
	2. Visit Heroku and deploy the latest state of master to the staging app
	3. Ensure the Dyno is running and open the logs page
	4. Visit r/sandbox and use testbot to test the changes
3. Regression test the important commands
	1. Get the list of important commands by typing `testbot commands`
	2. Ensure that the results you notice are because of Testbot!
	3. Check the logs page is error-free
4. Deploy the changes
	1. Check the change log thread for interrupts
	2. Let everyone know on the change log thread
	3. Deploy the code to production Dyno
	4. Watch the Dyno come back up
	5. Let everyone know on the change log thread
5. Test the deployment
	1. Check the Dyno's change diff
	2. "Test the changes" with Hubot
	3. "Regression test the important commands" with Hubot
6. Tidy up
	1. Turn off the staging Dyno
	2. Delete any deployed branches

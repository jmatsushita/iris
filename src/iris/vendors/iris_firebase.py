# Copyright (c) LinkedIn Corporation. All rights reserved. Licensed under the BSD-2 Clause license.
# See LICENSE in the project root for license information.

import logging
from iris.constants import PUSH_SUPPORT
import firebase_admin
from firebase_admin import credentials, messaging
from firebase_admin.messaging import ApsAlert, Aps, AndroidNotification, AndroidConfig, APNSPayload, APNSConfig, Message
import sys
import json
import threading
import wf_secrets
import datetime

logger = logging.getLogger(__name__)

# Basic arguments. You should extend this function with the push features you
# want to use, or simply pass in a `PushMessage` object.
def send_push_message(self, token, message, subject, extra=None):
    default_app = self.default_app

    # All data key:values must be strings
    notify_data = {'title': str(subject),
                   'body': str(message),
                   'sound': 'waytone'}

    try:
        message = messaging.Message(
            data = notify_data,
            token = token,
            notification = messaging.Notification(
                title = subject,
                body = message,
            ),
            android=messaging.AndroidConfig(
                ttl=datetime.timedelta(seconds=3600),
                priority='high',
                notification=messaging.AndroidNotification(
                    sound = 'waytone',
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound = 'waytone.caf'),
                ),
            ),
        )
        # Send a message to the device corresponding to the provided
        # registration token.
        response = messaging.send(message, app=self.default_app)
        logger.info('Push Message sent to %s', token)

    except Exception as e:
        print 'Error while sending push message: %s', e.message
        logger.error('Error while sending push message: %s', e.message)

class iris_firebase(object):
    supports = frozenset([PUSH_SUPPORT])

    def __init__(self, config):
        self.time_taken = 1
        try:
            # This is loaded because GCP objects dont like to be deepcopy'd
            firebase_creds = json.load(open('/wayfair/data/iris/latest/configs/firebase.json'))
            # Encoding key produces \\ on newlines, which are necessary
            firebase_creds['private_key'] = wf_secrets.get('notify_firebase').replace('\\n', '\n')
            logger.info("Loading Firebase Creds...")
            cred = credentials.Certificate(firebase_creds)
            self.default_app = firebase_admin.initialize_app(cred, name=threading.current_thread().name)
            logger.info("Firebase Creds loaded.")
        except Exception as e:
            logger.exception(e.message)

    def send(self, message):
        logger.info('message: %s', message)
        send_push_message(self,message['destination'], message['body'], message['subject'], { 'priority': message['priority'] })
        return self.time_taken

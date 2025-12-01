const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onRequest} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Cloud Function triggered when an order status changes
 * Sends push notification to the customer
 */
exports.onOrderStatusChange = onDocumentUpdated(
  {
    document: 'orders/{orderId}',
    region: 'us-central1',
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const orderId = event.params.orderId;

    // Only send notification if status actually changed
    if (before.status === after.status) {
      console.log(`Order ${orderId} status unchanged: ${after.status}`);
      return null;
    }

    const status = after.status;
    const customerId = after.customerId;
    const customerFcmToken = after.customerFcmToken;

    // Determine notification content based on status
    let title, body, notificationType;

    switch (status) {
      case 'accepted':
        title = 'Order Accepted';
        body = 'A driver has accepted your order';
        notificationType = 'order_accepted';
        break;
      case 'in_transit':
        title = 'Order In Transit';
        body = 'Your order is on the way';
        notificationType = 'order_in_transit';
        break;
      case 'completed':
        title = 'Order Completed';
        body = 'Your order has been delivered';
        notificationType = 'order_completed';
        break;
      default:
        // Don't send notification for other statuses
        console.log(`No notification needed for status: ${status}`);
        return null;
    }

    // Get FCM token from order or user document
    let fcmToken = customerFcmToken;

    if (!fcmToken || fcmToken.trim() === '') {
      console.log(`No FCM token in order ${orderId}, fetching from user document...`);
      try {
        const userDoc = await db.collection('users').doc(customerId).get();
        if (userDoc.exists) {
          fcmToken = userDoc.data()?.fcmToken;
        }
      } catch (error) {
        console.error(`Error fetching user FCM token: ${error}`);
      }
    }

    if (!fcmToken || fcmToken.trim() === '') {
      console.log(`Cannot send notification for order ${orderId} - no FCM token available`);
      return null;
    }

    // Send notification via FCM
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: notificationType,
        orderId: orderId,
        status: status,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'order_updates',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await messaging.send(message);
      console.log(`✅ Successfully sent notification for order ${orderId}: ${response}`);
      return null;
    } catch (error) {
      console.error(`❌ Error sending notification for order ${orderId}:`, error);
      
      // If FCM token is invalid, try to update it
      if (error.code === 'messaging/invalid-registration-token' || 
          error.code === 'messaging/registration-token-not-registered') {
        console.log(`Invalid FCM token for order ${orderId}, removing from order document`);
        try {
          await db.collection('orders').doc(orderId).update({
            customerFcmToken: admin.firestore.FieldValue.delete(),
          });
        } catch (updateError) {
          console.error(`Error removing invalid FCM token: ${updateError}`);
        }
      }
      
      throw error;
    }
  }
);

/**
 * Cloud Function to process pending notifications
 * This can be triggered manually or via a scheduled function
 */
exports.processPendingNotifications = onRequest(
  {
    region: 'us-central1',
  },
  async (req, res) => {
    try {
      console.log('Processing pending notifications...');
      
      const pendingNotifications = await db
        .collection('pending_notifications')
        .where('attempts', '<', 3) // Only process notifications with less than 3 attempts
        .limit(100) // Process up to 100 at a time
        .get();

      if (pendingNotifications.empty) {
        console.log('No pending notifications to process');
        res.json({ success: true, processed: 0 });
        return;
      }

      const batch = db.batch();
      let successCount = 0;
      let failureCount = 0;

      for (const doc of pendingNotifications.docs) {
        const notification = doc.data();
        const { fcmToken, title, body, data } = notification;

        if (!fcmToken || fcmToken.trim() === '') {
          console.log(`Skipping notification ${doc.id} - no FCM token`);
          batch.delete(doc.ref);
          continue;
        }

        const message = {
          token: fcmToken,
          notification: {
            title: title,
            body: body,
          },
          data: {
            ...Object.keys(data || {}).reduce((acc, key) => {
              acc[key] = String(data[key]);
              return acc;
            }, {}),
            type: data?.type || 'general',
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'order_updates',
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        try {
          await messaging.send(message);
          console.log(`✅ Successfully sent pending notification ${doc.id}`);
          batch.delete(doc.ref);
          successCount++;
        } catch (error) {
          console.error(`❌ Error sending pending notification ${doc.id}:`, error);
          
          // Increment attempts
          const attempts = (notification.attempts || 0) + 1;
          
          if (error.code === 'messaging/invalid-registration-token' || 
              error.code === 'messaging/registration-token-not-registered') {
            // Delete invalid tokens
            batch.delete(doc.ref);
          } else if (attempts >= 3) {
            // Delete after 3 failed attempts
            batch.delete(doc.ref);
          } else {
            // Update attempts count
            batch.update(doc.ref, { attempts: attempts });
          }
          
          failureCount++;
        }
      }

      await batch.commit();
      
      console.log(`Processed ${successCount} successful, ${failureCount} failed notifications`);
      res.json({ 
        success: true, 
        processed: successCount + failureCount,
        successful: successCount,
        failed: failureCount,
      });
    } catch (error) {
      console.error('Error processing pending notifications:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  }
);

/**
 * Scheduled function to process pending notifications every 5 minutes
 */
exports.scheduledProcessPendingNotifications = onSchedule(
  {
    schedule: 'every 5 minutes',
    region: 'us-central1',
  },
  async (event) => {
    console.log('Scheduled processing of pending notifications');
    
    try {
      const pendingNotifications = await db
        .collection('pending_notifications')
        .where('attempts', '<', 3)
        .limit(100)
        .get();

      if (pendingNotifications.empty) {
        console.log('No pending notifications to process');
        return null;
      }

      const batch = db.batch();
      let successCount = 0;

      for (const doc of pendingNotifications.docs) {
        const notification = doc.data();
        const { fcmToken, title, body, data } = notification;

        if (!fcmToken || fcmToken.trim() === '') {
          batch.delete(doc.ref);
          continue;
        }

        const message = {
          token: fcmToken,
          notification: {
            title: title,
            body: body,
          },
          data: {
            ...Object.keys(data || {}).reduce((acc, key) => {
              acc[key] = String(data[key]);
              return acc;
            }, {}),
            type: data?.type || 'general',
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'order_updates',
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        try {
          await messaging.send(message);
          batch.delete(doc.ref);
          successCount++;
        } catch (error) {
          const attempts = (notification.attempts || 0) + 1;
          
          if (error.code === 'messaging/invalid-registration-token' || 
              error.code === 'messaging/registration-token-not-registered') {
            batch.delete(doc.ref);
          } else if (attempts >= 3) {
            batch.delete(doc.ref);
          } else {
            batch.update(doc.ref, { attempts: attempts });
          }
        }
      }

      await batch.commit();
      console.log(`Scheduled processing completed: ${successCount} notifications sent`);
      return null;
    } catch (error) {
      console.error('Error in scheduled processing:', error);
      throw error;
    }
  }
);

/**
 * Cloud Function to send notification to new order (notify drivers)
 * Triggered when a new order is created
 */
exports.onNewOrder = onDocumentCreated(
  {
    document: 'orders/{orderId}',
    region: 'us-central1',
  },
  async (event) => {
    const order = event.data.data();
    const orderId = event.params.orderId;

    // Only notify if order is pending
    if (order.status !== 'pending') {
      console.log(`Order ${orderId} is not pending, skipping driver notification`);
      return null;
    }

    try {
      // Get all drivers
      const driversSnapshot = await db
        .collection('users')
        .where('role', 'in', ['driver', 'both'])
        .get();

      if (driversSnapshot.empty) {
        console.log('No drivers found to notify');
        return null;
      }

      const tokens = [];
      driversSnapshot.forEach((doc) => {
        const fcmToken = doc.data()?.fcmToken;
        if (fcmToken && fcmToken.trim() !== '') {
          tokens.push(fcmToken);
        }
      });

      if (tokens.length === 0) {
        console.log('No driver FCM tokens available');
        return null;
      }

      const gasQuantity = order.gasQuantity || 0;
      const address = order.address || 'Unknown address';

      // Send multicast message to all drivers
      const message = {
        notification: {
          title: 'New Order Available',
          body: `${gasQuantity.toString()} gallons at ${address}`,
        },
        data: {
          type: 'new_order',
          orderId: orderId,
          address: address,
          gasQuantity: gasQuantity.toString(),
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'order_updates',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Send in batches of 500 (FCM limit)
      const batchSize = 500;
      for (let i = 0; i < tokens.length; i += batchSize) {
        const batch = tokens.slice(i, i + batchSize);
        const multicastMessage = {
          ...message,
          tokens: batch,
        };

        try {
          const response = await messaging.sendEachForMulticast(multicastMessage);
          console.log(`✅ Sent new order notification to ${response.successCount} drivers (batch ${i / batchSize + 1})`);
          if (response.failureCount > 0) {
            console.log(`⚠️ Failed to send to ${response.failureCount} drivers`);
          }
        } catch (error) {
          console.error(`❌ Error sending batch notification:`, error);
        }
      }

      return null;
    } catch (error) {
      console.error(`Error notifying drivers of new order ${orderId}:`, error);
      throw error;
    }
  }
);

// index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onBookingCreated = functions.firestore
  .document('Bookings/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    const newData = change.after.data();
    const oldData = change.before.data();

    const newBookings = newData?.Bookings || [];
    const oldBookings = oldData?.Bookings || [];
    const addedOrUpdatedBookings = newBookings.filter((newBooking) => {
      const oldBooking = oldBookings.find(
        (b) => b.date.seconds === newBooking.date.seconds
      );
      return !oldBooking || oldBooking.status !== newBooking.status;
    });

    for (const booking of addedOrUpdatedBookings) {
      const doctorId = booking.doctorId;
      const patientId = userId;
      const status = booking.status;

      let recipientId, notificationType;
      if (status === 'Pending') {
        recipientId = doctorId;
        notificationType = 'new_booking';
      } else if (status === 'Active') {
        recipientId = patientId;
        notificationType = 'status_update';
      } else if (status === 'Terminated') {
        recipientId = patientId;
        notificationType = 'cancelled';
      } else {
        continue;
      }

      const userDoc = await admin.firestore()
        .collection('Users')
        .doc(recipientId)
        .get();
      const fcmToken = userDoc.data()?.fcmToken;
      if (!fcmToken) continue;

      const message = {
        token: fcmToken,
        notification: {
          title: status === 'Pending' ? 'New Booking Request' :
                 status === 'Active' ? 'Booking Accepted' : 'Booking Cancelled',
          body: status === 'Pending'
            ? `New booking request from patient on ${new Date(booking.date.seconds * 1000).toLocaleString()}`
            : status === 'Active'
            ? `Your booking on ${new Date(booking.date.seconds * 1000).toLocaleString()} has been accepted`
            : `Your booking on ${new Date(booking.date.seconds * 1000).toLocaleString()} has been cancelled`,
        },
        data: {
          type: notificationType,
          bookingDate: booking.date.seconds.toString(),
          userId: patientId,
          doctorId: doctorId,
        },
      };

      await admin.messaging().send(message);
    }
  });

exports.sendBookingReminders = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const bookingsSnapshot = await admin.firestore().collectionGroup('Bookings').get();
    for (const doc of bookingsSnapshot.docs) {
      const bookings = doc.data().Bookings || [];
      for (const booking of bookings) {
        const bookingDate = new Date(booking.date.seconds * 1000);
        if (
          booking.status === 'Active' &&
          bookingDate.getDate() === tomorrow.getDate() &&
          bookingDate.getMonth() === tomorrow.getMonth() &&
          bookingDate.getFullYear() === tomorrow.getFullYear()
        ) {
          const userDoc = await admin.firestore()
            .collection('Users')
            .doc(doc.id)
            .get();
          const fcmToken = userDoc.data()?.fcmToken;
          if (fcmToken) {
            await admin.messaging().send({
              token: fcmToken,
              notification: {
                title: 'Appointment Reminder',
                body: `Your appointment is scheduled for ${bookingDate.toLocaleString()}`,
              },
              data: {
                type: 'reminder',
                bookingDate: booking.date.seconds.toString(),
                doctorId: booking.doctorId,
              },
            });
          }
        }
      }
    }
  });

// Push notification for SocialHubb messages
exports.onMessageCreated = functions.firestore
  .document('Chats/{chatId}/Messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const chatId = context.params.chatId;
    const senderId = messageData.senderId;
    const recipientId = messageData.recipientId;

    // Don't send notification if user is sending to themselves
    if (senderId === recipientId) return;

    try {
      // Get recipient user data
      const recipientDoc = await admin.firestore()
        .collection('Users')
        .doc(recipientId)
        .get();
      
      if (!recipientDoc.exists) return;

      const recipientData = recipientDoc.data();
      const fcmToken = recipientData?.fcmToken;

      if (!fcmToken) return;

      // Get sender user data for notification
      const senderDoc = await admin.firestore()
        .collection('Users')
        .doc(senderId)
        .get();
      
      const senderData = senderDoc.data();
      const senderName = senderData ? `${senderData.Fname || ''} ${senderData.Lname || ''}`.trim() : 'Someone';
      
      // Get message content
      const messageContent = messageData.content || '';
      const messageType = messageData.type || 'text';
      const preview = messageType === 'audio' ? '[Voice message]' : 
                     (messageContent.length > 50 ? messageContent.substring(0, 50) + '...' : messageContent);

      // Send notification
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: senderName,
          body: preview,
        },
        data: {
          type: 'new_message',
          chatId: chatId,
          senderId: senderId,
          recipientId: recipientId,
          messageType: messageType,
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'messages',
          },
        },
      });
    } catch (error) {
      console.error('Error sending message notification:', error);
    }
  });
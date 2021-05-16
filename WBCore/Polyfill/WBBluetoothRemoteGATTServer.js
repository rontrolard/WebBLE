/*global
        atob, Event, nslog, uk, window
*/
// https://webbluetoothcg.github.io/web-bluetooth/ interface

(function () {
  'use strict';

  const wb = uk.co.greenparksoftware.wb;
  const wbutils = uk.co.greenparksoftware.wbutils;

  nslog('Create BluetoothRemoteGATTServer');
  wb.BluetoothRemoteGATTServer = function (webBluetoothDevice) {
    if (webBluetoothDevice === undefined) {
      throw new Error('Attempt to create BluetoothRemoteGATTServer with no device');
    }
    wbutils.defineROProperties(this, {device: webBluetoothDevice});
    this.connected = false;
    this.connectionTransactionIDs = [];
  };
  wb.BluetoothRemoteGATTServer.prototype = {
    connect: function () {
      let self = this;
      let tid = wb.native.getTransactionID();
      this.connectionTransactionIDs.push(tid);
      return this.sendMessage('connectGATT', {callbackID: tid}).then(function () {
        self.connected = true;
        wb.native.registerDeviceForNotifications(self.device);
        self.connectionTransactionIDs.splice(
          self.connectionTransactionIDs.indexOf(tid),
          1
        );

        return self;
      });
    },
    disconnect: function () {
      this.connectionTransactionIDs.forEach((tid) => wb.native.cancelTransaction(tid));
      this.connectionTransactionIDs = [];
      if (!this.connected) {
        return;
      }
      this.connected = false;

      // since we've set connected false this event won't be generated
      // by the shortly to be dispatched disconnect event.
      this.device.dispatchEvent(new wb.BluetoothEvent('gattserverdisconnected', this.device));
      wb.native.unregisterDeviceForNotifications(this.device);
      // If there were two devices pointing at the same underlying device
      // this would break both connections, so not really what we want,
      // but leave it like this till someone complains.
      this.sendMessage('disconnectGATT');
    },
    getPrimaryService: function (UUID) {
      let canonicalUUID = window.BluetoothUUID.getService(UUID);
      let self = this;
      return this.sendMessage(
        'getPrimaryService',
        {data: {serviceUUID: canonicalUUID}}
      ).then(() => new wb.BluetoothRemoteGATTService(
        self.device,
        canonicalUUID,
        true
      ));
    },

    getPrimaryServices: async function () {
      const serviceUUIDs = await this.sendMessage('getPrimaryServices');
      return serviceUUIDs.map(uuid => new wb.BluetoothRemoteGATTService(
        this.device,
        window.BluetoothUUID.getService(uuid),
        true,
      ));
    },
    sendMessage: function (type, messageParms) {
      messageParms = messageParms || {};
      messageParms.data = messageParms.data || {};
      messageParms.data.deviceId = this.device.id;
      return wb.native.sendMessage('device:' + type, messageParms);
    },
    toString: function () {
      return `BluetoothRemoteGATTServer(${this.device.toString()})`;
    }
  };
  nslog('Created');
})();

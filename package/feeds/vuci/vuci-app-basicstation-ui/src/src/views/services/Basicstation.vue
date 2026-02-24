<template>
  <vuci-form config="basicstation" @save="handleSave" v-slot="{ uciData }">
    <div class="lorawan-build-tag">
      {{ $t('LoRaWAN UI Build') }}: {{ buildVersion }} ({{ $t('Build') }} {{ buildNumber }})
    </div>
    <a-tabs :default-active-key="activeTab" class="basicstation-tabs">
      <a-tab-pane key="general" :tab="$t('General Settings')">
        <!-- Station Identity and Logging -->

        <vuci-named-section name="station" :title="$t('Station Identity and Logging')" v-slot="{ s }"
          :uci-data="uciData" :endpoints="[{ endpoint: 'basicstation/config' }]" data-key="station">
          <vuci-form-item-input :uci-section="s" :label="$t('Interface for station ID generation')" name="idGenIf"
            required :help="$t('Station ID is derived from the MAC address of the chosen interface')" />
          <vuci-form-item-input :uci-section="s" :label="$t('Station ID')" name="stationid"
            :help="$t('Click save and apply to generate station ID')" />
          <vuci-form-item-select :uci-section="s" :label="$t('Log Level')" name="log_level"
            :options="logLevelOptions" />
          <vuci-form-item-input :uci-section="s" :label="$t('Log Size (MB)')" name="log_size" type="number" />
          <vuci-form-item-input :uci-section="s" :label="$t('Log Rotate')" name="log_rotate" type="number" />
        </vuci-named-section>

        <!-- Authentication -->
        <vuci-named-section name="auth" :title="$t('Authentication')" v-slot="{ s }" :uci-data="uciData"
          :endpoints="[{ endpoint: 'basicstation/config' }]" data-key="auth">
          <vuci-form-item-select :uci-section="s" :label="$t('Credentials')" name="cred" :options="credOptions"
            :help="$t('Credentials for LNS (TC) or CUPS (CUPS)')" />
          <vuci-form-item-select :uci-section="s" :label="$t('Authentication mode')" name="mode" :options="modeOptions"
            :help="$t('Authentication mode for server connection')" />
          <vuci-form-item-input :uci-section="s" :label="$t('Server address')" name="addr" required />
          <vuci-form-item-input :uci-section="s" :label="$t('Port')" name="port" required />
          <!-- Token for serverAndClientToken mode -->
          <vuci-form-item-input v-if="s.mode === 'serverAndClientToken'" :uci-section="s"
            :label="$t('Authorization token')" name="token" required />
          <!-- Certificate uploads for serverAndClient mode -->
          <tlt-form-model-item v-if="s.mode === 'serverAndClient'" :label="$t('Private key (tc.key)')"
            :help="$t('Key will be saved to /etc/basicstation/tc.key')">
            <tlt-upload instant name="key" action="/api/basicstation/upload" />
          </tlt-form-model-item>
          <tlt-form-model-item v-if="s.mode === 'serverAndClient'" :label="$t('Client certificate (tc.crt)')"
            :help="$t('Certificate will be saved to /etc/basicstation/tc.crt')">
            <tlt-upload instant name="crt" action="/api/basicstation/upload" />
          </tlt-form-model-item>
          <!-- CA certificate for any TLS mode -->
          <tlt-form-model-item v-if="s.mode !== 'no'" :label="$t('CA certificate (tc.trust)')"
            :help="$t('Certificate will be saved to /etc/basicstation/tc.trust')">
            <tlt-upload instant name="trust" action="/api/basicstation/upload" />
          </tlt-form-model-item>
        </vuci-named-section>

        <!-- Radio Configuration -->
        <vuci-named-section name="sx130x" :title="$t('Radio Configuration')" v-slot="{ s }" :uci-data="uciData"
          :endpoints="[{ endpoint: 'basicstation/config' }]" data-key="sx130x">
          <vuci-form-item-select :uci-section="s" :label="$t('Communication interface')" name="comif"
            :options="[['usb', 'USB']]" :help="$t('Currently only USB devices are supported')" />
          <vuci-form-item-input :uci-section="s" :label="$t('Device path')" name="devpath" required
            placeholder="/dev/ttyACM0" />
          <vuci-form-item-switch :uci-section="s" :label="$t('PPS')" name="pps"
            :help="$t('PPS (pulse per second) provided by GPS device or other source')" />
          <vuci-form-item-switch :uci-section="s" :label="$t('Public network')" name="public"
            :help="$t('Public or private LoRaWAN network')" />
          <vuci-form-item-select :uci-section="s" :label="$t('Clock source')" name="clksrc"
            :options="[['0', 'Radio 0'], ['1', 'Radio 1']]" />
          <vuci-form-item-select :uci-section="s" :label="$t('Radio 0')" name="radio0" :options="rfConfOptions" />
          <vuci-form-item-select :uci-section="s" :label="$t('Radio 1')" name="radio1" :options="rfConfOptions" />
        </vuci-named-section>


      </a-tab-pane>

      <a-tab-pane key="advanced" :tab="$t('Advanced Settings')">
        <!-- RF Configuration -->
        <vuci-typed-section type="rfconf" :title="$t('RF Configuration')" :columns="rfConfColumns" :uci-data="uciData"
          :endpoints="[{ endpoint: 'basicstation/config/rfconf' }]" data-key="rfconf">
          <template #type="{ s }">
            <vuci-form-item-select :uci-section="s" name="type" :options="[['SX1250', 'SX1250']]" />
          </template>
          <template #txEnable="{ s }">
            <vuci-form-item-switch :uci-section="s" name="txEnable" />
          </template>
          <template #freq="{ s }">
            <vuci-form-item-input :uci-section="s" name="freq" />
          </template>
          <template #antennaGain="{ s }">
            <vuci-form-item-input :uci-section="s" name="antennaGain" />
          </template>
          <template #rssiOffset="{ s }">
            <vuci-form-item-input :uci-section="s" name="rssiOffset" />
          </template>
          <template #useRssiTcomp="{ s }">
            <vuci-form-item-select :uci-section="s" name="useRssiTcomp" :options="rssiTcompOptions" />
          </template>
        </vuci-typed-section>

        <!-- RSSI Tcomp -->
        <vuci-typed-section type="rssitcomp" :title="$t('RSSI Tcomp')" :columns="rssiTcompColumns" :uci-data="uciData"
          :endpoints="[{ endpoint: 'basicstation/config/rssitcomp' }]" data-key="rssitcomp" addremove>
          <template #coeff_a="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_a" />
          </template>
          <template #coeff_b="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_b" />
          </template>
          <template #coeff_c="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_c" />
          </template>
          <template #coeff_d="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_d" />
          </template>
          <template #coeff_e="{ s }">
            <vuci-form-item-input :uci-section="s" name="coeff_e" />
          </template>
        </vuci-typed-section>

        <!-- TX Gain Lookup Table -->
        <vuci-typed-section type="txlut" :title="$t('TX Gain Lookup Table')" :columns="txLutColumns" :uci-data="uciData"
          :endpoints="[{ endpoint: 'basicstation/config/txlut' }]" data-key="txlut" addremove>
          <template #rfPower="{ s }">
            <vuci-form-item-input :uci-section="s" name="rfPower" />
          </template>
          <template #paGain="{ s }">
            <vuci-form-item-switch :uci-section="s" name="paGain" />
          </template>
          <template #pwrIdx="{ s }">
            <vuci-form-item-input :uci-section="s" name="pwrIdx" type="number" />
          </template>
          <template #usedBy="{ s }">
            <vuci-form-item-select :uci-section="s" name="usedBy" :options="rfConfOptions" multiple />
          </template>
        </vuci-typed-section>
      </a-tab-pane>

      <a-tab-pane key="log" :tab="$t('Log Messages')">
        <tlt-card :title="$t('Log Messages')">
          <template #title>
            <span>{{ $t('Log Messages') }}</span>
            <a-tag v-if="serviceRunning" color="green" style="margin-left: 10px">{{ $t('Running') }}</a-tag>
            <a-tag v-else color="red" style="margin-left: 10px">{{ $t('Stopped') }}</a-tag>
          </template>
          <div class="log-container" ref="logContainer">
            <pre>{{ logContent }}</pre>
          </div>
          <template #extra>
            <a-space>
              <a-switch v-model="autoRefresh" :checked-children="$t('Auto-refresh ON')"
                :un-checked-children="$t('Auto-refresh OFF')" />
              <a-button type="danger" size="small" icon="delete" @click="clearLogs">{{ $t('Clear') }}</a-button>
              <a-button type="primary" size="small" icon="reload" @click="fetchLogs">{{ $t('Refresh') }}</a-button>
            </a-space>
          </template>
        </tlt-card>
      </a-tab-pane>
    </a-tabs>
  </vuci-form>
</template>

<script>
import buildInfo from '../../../build.json'

export default {
  props: {
    tab: {
      type: String,
      default: 'general'
    }
  },
  data() {
    return {
      activeTab: this.tab || 'general',
      buildVersion: buildInfo.buildVersion || 'Fallback',
      buildNumber: buildInfo.buildNumber || 0,
      logContent: "",
      rfConfOptions: [],
      rssiTcompOptions: [],
      credOptions: [
        ["tc", this.$t("TC")],
        ["cups", this.$t("CUPS")],
      ],
      modeOptions: [
        ["no", this.$t("No Authentication")],
        ["server", this.$t("TLS Server Authentication")],
        ["serverAndClient", this.$t("TLS Server and Client Authentication")],
        ["serverAndClientToken", this.$t("TLS Server Authentication and Client Token")],
      ],
      logLevelOptions: [
        ["XDEBUG", "xdebug"],
        ["DEBUG", "debug"],
        ["VERBOSE", "verbose"],
        ["INFO", "info"],
        ["NOTICE", "notice"],
        ["WARNING", "warning"],
        ["ERROR", "error"],
        ["CRITICAL", "critical"],
      ],
      rfConfColumns: [
        { name: "type", label: this.$t("Type") },
        { name: "txEnable", label: this.$t("Tx enable") },
        { name: "freq", label: this.$t("Frequency") },
        { name: "antennaGain", label: this.$t("Antenna Gain") },
        { name: "rssiOffset", label: this.$t("RSSI Offset") },
        { name: "useRssiTcomp", label: this.$t("RSSI Tcomp") },
      ],
      rssiTcompColumns: [
        { name: "coeff_a", label: this.$t("Coeff A") },
        { name: "coeff_b", label: this.$t("Coeff B") },
        { name: "coeff_c", label: this.$t("Coeff C") },
        { name: "coeff_d", label: this.$t("Coeff D") },
        { name: "coeff_e", label: this.$t("Coeff E") },
      ],
      txLutColumns: [
        { name: "rfPower", label: this.$t("RF Power") },
        { name: "paGain", label: this.$t("PA Enable") },
        { name: "pwrIdx", label: this.$t("Power Index") },
        { name: "usedBy", label: this.$t("Used By") },
      ],
      autoRefresh: false,
      refreshTimer: null,
      serviceRunning: false
    };
  },
  async created() {
    await this.logAllUci();
    await this.loadUciOptions();
    await this.fetchLogs();
    await this.fetchStatus();
  },
  destroyed() {
    this.stopRefresh();
  },
  watch: {
    autoRefresh(val) {
      if (val) {
        this.startRefresh();
      } else {
        this.stopRefresh();
      }
    }
  },
  methods: {

    async loadUciOptions() {
      try {
        const rfconfRes = await this.$axios.get("/api/basicstation/rfconf");
        console.log("--- BASICSTATION RFCONF OPTIONS ---");
        console.log(JSON.stringify(rfconfRes, null, 2));
        const rfconfData = rfconfRes.data.data || rfconfRes.data || rfconfRes;
        const rfArray = Array.isArray(rfconfData) ? rfconfData : Object.values(rfconfData || {});
        if (rfArray.length > 0) {
          this.rfConfOptions = rfArray.map(s => [s['.name'], s['.name']]);
        }
        const rssitcompRes = await this.$axios.get("/api/basicstation/rssitcomp");
        console.log("--- BASICSTATION RSSITCOMP OPTIONS ---");
        console.log(JSON.stringify(rssitcompRes, null, 2));
        const rssitcompData = rssitcompRes.data.data || rssitcompRes.data || rssitcompRes;
        const rssiArray = Array.isArray(rssitcompData) ? rssitcompData : Object.values(rssitcompData || {});
        if (rssiArray.length > 0) {
          this.rssiTcompOptions = rssiArray.map(s => [s['.name'], s['.name']]);
        }
      } catch (e) {
        console.error("Failed to load options from API", e);
      }
    },
    async fetchLogs(silent = false) {
      if (!silent && this.$spin) this.$spin();
      try {
        const response = await this.$axios.get("/api/basicstation/log");
        const body = response.data || response;
        this.logContent = body.log || "";
        this.$nextTick(() => {
          this.scrollToBottom();
        });
        if (silent) await this.fetchStatus();
      } catch (e) {
        if (!silent) this.$message.error(this.$t("Failed to fetch logs"));
      } finally {
        if (!silent && this.$spin) this.$spin(false);
      }
    },
    async clearLogs() {
      try {
        await this.$axios.get("/api/basicstation/clear_log");
        this.logContent = "";
        this.$message.success(this.$t("Logs cleared"));
      } catch (e) {
        this.$message.error(this.$t("Failed to clear logs"));
      }
    },
    async fetchStatus() {
      try {
        const response = await this.$axios.get("/api/basicstation/status");
        console.log("--- BASICSTATION STATUS ---");
        console.log(JSON.stringify(response, null, 2));
        const body = response.data || response;
        this.serviceRunning = !!body.running;
      } catch (e) {
        // Ignore status fetch errors
      }
    },
    startRefresh() {
      this.stopRefresh();
      this.refreshTimer = setInterval(() => {
        this.fetchLogs(true);
      }, 3000);
    },
    stopRefresh() {
      if (this.refreshTimer) {
        clearInterval(this.refreshTimer);
        this.refreshTimer = null;
      }
    },
    async logAllUci() {
      try {
        const config = await this.$axios.get("/api/basicstation/config");
        console.log("--- START BASICSTATION UCI DATA ---");
        console.log(JSON.stringify(config, null, 2));
        console.log("--- END BASICSTATION UCI DATA ---");
      } catch (e) {
        console.error("Failed to fetch all UCI data for logging", e);
      }
    },
    scrollToBottom() {
      const container = this.$refs.logContainer;
      if (container) {
        container.scrollTop = container.scrollHeight;
      }
    },
    async handleSave(uciData) {
      this.$spin(this.$t('Saving configuration...'));
      try {
        // Iterate through all sections in uciData and save them via action
        for (const stype in uciData) {
          const sections = uciData[stype];
          for (const sid in sections) {
            const data = sections[sid];
            // Determine service group for the API call
            // Named sections in vuci-form are usually under stype='config'
            // Typed sections are under their own stype name
            let group = stype;
            if (stype === 'basicstation' || stype === 'config') {
              if (sid === 'station' || sid === 'auth' || sid === 'sx130x') {
                group = sid;
              } else {
                group = 'config';
              }
            } else if (['rfconf', 'rssitcomp', 'txlut'].includes(stype)) {
              group = stype;
            }

            await this.$axios.post('/api/basicstation/actions/save_config', {
              data: {
                service_group: group,
                sid: sid,
                data: data
              }
            });
          }
        }
        this.$message.success(this.$t('Configuration saved successfully'));
      } catch (e) {
        this.$message.error(this.$t('Failed to save configuration'));
      } finally {
        this.$spin(false);
      }
    }
  },
};
</script>

<style scoped>
.log-container {
  max-height: 500px;
  overflow-y: auto;
  background: #f5f5f5;
  padding: 10px;
  border-radius: 4px;
}

pre {
  white-space: pre-wrap;
  word-wrap: break-word;
  margin: 0;
}

.basicstation-tabs {
  padding: 24px;
}

.lorawan-build-tag {
  padding: 8px 24px 0 24px;
  font-size: 12px;
  color: #666666;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
</style>

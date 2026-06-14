{{flutter_js}}
{{flutter_build_config}}

const cidBuildVersion = {{flutter_service_worker_version}};
const cidServiceWorkerResetKey = `cid_flutter_sw_reset_${cidBuildVersion}`;

async function resetLegacyFlutterServiceWorkers() {
  if (!("serviceWorker" in navigator)) {
    console.info("[Bootstrap] serviceWorker unsupported, skipping reset.");
    return;
  }

  if (sessionStorage.getItem(cidServiceWorkerResetKey) === "done") {
    console.info(
      `[Bootstrap] service worker reset already completed for build ${cidBuildVersion}.`,
    );
    return;
  }

  const registrations = await navigator.serviceWorker.getRegistrations();
  if (registrations.length === 0) {
    console.info("[Bootstrap] no service worker registrations found.");
    return;
  }

  console.info(
    `[Bootstrap] buildVersion=${cidBuildVersion} unregistering ${registrations.length} service worker registration(s).`,
  );

  await Promise.all(
    registrations.map((registration) =>
      registration.unregister().catch((error) => {
        console.warn("[Bootstrap] service worker unregister failed:", error);
        return false;
      }),
    ),
  );

  if ("caches" in window) {
    const cacheKeys = await caches.keys();
    console.info(
      `[Bootstrap] clearing ${cacheKeys.length} cache entr${cacheKeys.length === 1 ? "y" : "ies"}.`,
    );
    await Promise.all(
      cacheKeys.map((cacheKey) =>
        caches.delete(cacheKey).catch((error) => {
          console.warn(`[Bootstrap] cache delete failed for ${cacheKey}:`, error);
          return false;
        }),
      ),
    );
  }

  sessionStorage.setItem(cidServiceWorkerResetKey, "done");
  console.info(
    `[Bootstrap] legacy caches cleared for build ${cidBuildVersion}, reloading page.`,
  );
  window.location.reload();

  await new Promise(() => {});
}

(async function bootstrapCidDigitale() {
  console.info(`[Bootstrap] starting Flutter Web build ${cidBuildVersion}.`);
  await resetLegacyFlutterServiceWorkers();

  _flutter.loader.load({
    onEntrypointLoaded: async function onEntrypointLoaded(engineInitializer) {
      console.info(
        `[Bootstrap] Flutter entrypoint loaded for build ${cidBuildVersion}.`,
      );
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    },
  });
})();

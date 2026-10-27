# Alpha measurement correction

Original QA used alpha > 100 for body/feet bounds but omitted the threshold in manifest field names. This metadata correction records full nonzero, >=16, >100 and >=128 bounds. Generated PNG is unchanged and includes faint residual alpha beyond its body silhouette. It has NOT passed a clean-alpha gate. Full nonzero bbox is (20,48)-(162,160); body at >100 is (65,48)-(145,143). Pixel visibility must be checked in actual engine composition; do not infer clean transparency from thresholded bounds.

def _rpm_packages_impl(repository_ctx):
  # check that keys in "packages" and "packages_sha256" are the same
  for package in repository_ctx.attr.packages:
    if package not in repository_ctx.attr.packages_sha256:
      fail("Package named \"%s\" was not found in packages_sha256 of rule %s" % (package, repository_ctx.name))

  # download each package
  package_rule_dict = {}
  for package in repository_ctx.attr.packages:
    urllist = []
    for mirror in repository_ctx.attr.mirrors:
      # allow mirror URLs that don't end in /
      if mirror.endswith("/"):
        urllist.append(mirror + repository_ctx.attr.packages[package])
      else:
        urllist.append(mirror + "/" + repository_ctx.attr.packages[package])
    repository_ctx.download(
        urllist,
        output="rpms/" + repository_ctx.attr.packages_sha256[package] + ".rpm",
        sha256=repository_ctx.attr.packages_sha256[package],
        executable=False)
    package_rule_dict[package] = "@" + repository_ctx.name + "//rpms:" + repository_ctx.attr.packages_sha256[package] + ".rpm"

  # create the rpm_packages.bzl file that contains the package name : filename mapping
  repository_ctx.file("rpms/rpm_packages.bzl", repository_ctx.name + " = " + struct(**package_rule_dict).to_json(), executable=False)

  # create the BUILD file that globs all the rpm files
  repository_ctx.file("rpms/BUILD", """
package(default_visibility = ["//visibility:public"])
rpm_files = glob(["*.rpm"])
exports_files(rpm_files + ["rpm_packages.bzl"])
""", executable=False)

_rpm_packages = repository_rule(
    _rpm_packages_impl,
    attrs = {
        "distro_type": attr.string(
            doc = "the name of the distribution type, required - e.g. centos, fedora, or redhat",
        ),
        "distro": attr.string(
            doc = "the name of the distribution, required - e.g. 7 or 8",
        ),
        "arch": attr.string(
            doc = "the target package architecture, required - e.g. arm64 or amd64",
        ),
        "packages": attr.string_dict(
            doc = "a dictionary mapping packagename to package_path, required - e.g. {\"foo\":\"pool/main/f/foo/foo_1.2.3-0_amd64.rpm\"}",
        ),
        "packages_sha256": attr.string_dict(
            doc = "a dictionary mapping packagename to package_hash, required - e.g. {\"foo\":\"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef\"}",
        ),
        "mirrors": attr.string_list(
            doc = "a list of full URLs of the package repository, required - e.g. http://rpm.centos.org/centos",
        ),
        "components": attr.string_list(
            doc = "a list of accepted components - e.g. universe, multiverse",
        ),
        "pgp_key": attr.string(
            doc = "the name of the http_file rule that contains the pgp key that signed the Release file at <mirrorURL>/dists/<distro>/Release, required",
        ),
    },
)

def rpm_packages(**kwargs):
  _rpm_packages(**kwargs)
